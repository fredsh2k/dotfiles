#!/usr/bin/env python3
import argparse
import json
import os
import select
import subprocess
import time


CONNECT = {"msg_id": 257, "param": 0, "token": 0, "heartbeat": 1}


def extract_json(buffer):
    start = buffer.find("{")
    if start == -1:
        return None, ""
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(buffer)):
        char = buffer[index]
        if escaped:
            escaped = False
            continue
        if char == "\\":
            escaped = in_string
            continue
        if char == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return buffer[start : index + 1], buffer[index + 1 :]
    return None, buffer[start:]


def read_json(proc, timeout, buffer):
    end = time.time() + timeout
    while time.time() < end:
        payload, buffer = extract_json(buffer)
        if payload is not None:
            return payload, buffer
        ready, _, _ = select.select([proc.stdout], [], [], 0.2)
        if ready:
            chunk = os.read(proc.stdout.fileno(), 32768)
            if not chunk:
                return None, buffer
            buffer += chunk.decode("utf-8", "replace")
    return None, buffer


def send(proc, payload):
    proc.stdin.write(json.dumps(payload, separators=(",", ":")).encode())
    proc.stdin.flush()


def main():
    parser = argparse.ArgumentParser(
        description="Send JSON commands to YI camera through adb+nc"
    )
    parser.add_argument(
        "commands", nargs="*", help="JSON payloads; token:null is filled from session"
    )
    parser.add_argument("--host", default="192.168.42.1")
    parser.add_argument("--port", default="7878")
    parser.add_argument("--timeout", type=float, default=3.0)
    args = parser.parse_args()

    proc = subprocess.Popen(
        ["adb", "shell", "nc", args.host, args.port],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        buffer = ""
        send(proc, CONNECT)
        token = None
        while True:
            line, buffer = read_json(proc, args.timeout, buffer)
            if line is None:
                raise SystemExit("timed out waiting for camera session response")
            print(line)
            try:
                response = json.loads(line)
            except json.JSONDecodeError:
                continue
            if response.get("msg_id") == 257 and response.get("rval") == 0:
                token = response.get("param")
                break

        for raw in args.commands:
            payload = json.loads(raw)
            if payload.get("token") is None:
                payload["token"] = token
            send(proc, payload)
            while True:
                line, buffer = read_json(proc, args.timeout, buffer)
                if line is None:
                    break
                print(line)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
