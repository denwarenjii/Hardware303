#!/usr/bin/env python3
import sys

def main():
    fh_in = sys.stdin
    fh_out = sys.stdout

    while True:
        # incoming values have newline
        l = fh_in.readline()
        if not l:
            return 0

        # Strip whitespace/newline to process the raw token
        raw_val = l.strip()

        # If it's a blank line, just echo a newline back
        if not raw_val:
            fh_out.write("\n")
            fh_out.flush()
            continue

        try:
            # Auto-detect format from GTKWave:
            # If it's pure binary (only 0s, 1s, or X/Z) and long, parse as base 2
            if all(c in '01XZUxzu' for c in raw_val) and len(raw_val) > 4:
                x = int(raw_val, 2)
            else:
                # Try hex first, fallback to decimal if hex fails
                try:
                    x = int(raw_val, 16)
                except ValueError:
                    x = int(raw_val, 10)

            # The signed Q1.14 math one-liner
            q_val = ((x + 32768) % 65536 - 32768) / 16384
            
            # outgoing filtered values must have a newline
            fh_out.write(f"{q_val:.4f}\n")

        except Exception:
            # If there are X/Z states or parsing fails, pass back original token with a newline
            fh_out.write(f"{raw_val}\n")
            
        fh_out.flush()

if __name__ == '__main__':
    sys.exit(main())
