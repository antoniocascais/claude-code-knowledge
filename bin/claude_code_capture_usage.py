#!/usr/bin/env python3
"""
Capture /usage output from Claude interactive TUI using pexpect.
Version 2: Improved debugging and pattern matching.
"""
import io
import re
import sys
import time

try:
    import pexpect
except ImportError as import_error:
    PEXPECT_IMPORT_ERROR = import_error
    pexpect = None
else:
    PEXPECT_IMPORT_ERROR = None


ANSI_ESCAPE_RE = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")


def strip_ansi(text: str) -> str:
    """Remove ANSI escape sequences and stray carriage returns."""
    return ANSI_ESCAPE_RE.sub("", text).replace("\r", "")


def extract_usage_section(clean_text: str):
    """Extract the Usage tab content from cleaned Claude output."""
    lines = [line.rstrip() for line in clean_text.splitlines()]

    candidates = [idx for idx, line in enumerate(lines)
                  if "Settings:" in line and "Usage" in line]
    if candidates:
        # Prefer the last occurrence to capture the fully rendered dialog
        start_idx = candidates[-1]

        if start_idx > 0:
            prev_line = lines[start_idx - 1].strip()
            if prev_line.startswith("─"):
                start_idx -= 1

        end_idx = start_idx + 1
        while end_idx < len(lines):
            current = lines[end_idx].strip()
            if not current:
                end_idx += 1
                continue
            if current.startswith(">") or current.startswith("·"):
                break
            if current.startswith("Pressing Escape") or current.startswith("Sending /exit"):
                break
            if current.startswith("Status dialog dismissed"):
                break
            end_idx += 1

        usage_lines = [line.rstrip() for line in lines[start_idx:end_idx]]
        usage_block = "\n".join(usage_lines).strip()
        if usage_block:
            return usage_block

    # Fallback for Claude Code v2.0.28+ "status strip" layout
    status_candidates = [
        idx for idx, line in enumerate(lines)
        if "Session:" in line and "┌─ project" in line
    ]
    if not status_candidates:
        status_candidates = [
            idx for idx, line in enumerate(lines)
            if "Session:" in line and "Week:" in line
        ]

    if not status_candidates:
        return None

    start_idx = status_candidates[-1]
    end_idx = start_idx + 1
    collected = [lines[start_idx].rstrip()]
    terminal_prefixes = (">", "-- INSERT --", "/exit", "Pressing", "Sending", "Try \"", "Usage details saved")

    while end_idx < len(lines):
        current_line = lines[end_idx]
        stripped = current_line.strip()
        if not stripped:
            collected.append(current_line.rstrip())
            end_idx += 1
            continue
        if stripped.startswith(terminal_prefixes):
            break
        if "Thinking on" in stripped:
            break
        if stripped.startswith("Status dialog dismissed"):
            break
        collected.append(current_line.rstrip())
        end_idx += 1

    usage_block = "\n".join(line.rstrip() for line in collected).strip()
    return usage_block or None

def capture_slash_command(command="/usage", timeout=30, debug=False, wait_time=5, silent=False):
    """
    Spawn Claude TUI, send a slash command, and capture the output.

    Args:
        command: Slash command to execute (e.g., "/usage", "/cost")
        timeout: Maximum time to wait for responses
        debug: If True, show all interactions
        wait_time: Seconds to wait after sending command (default: 5)

    Returns:
        str: Captured output from the command
    """
    if pexpect is None:
        raise RuntimeError("pexpect is not available")

    def emit(message=""):
        if not silent:
            print(message)

    emit(f"Spawning Claude TUI to execute '{command}'...\n")

    # Spawn the claude process with a PTY
    child = pexpect.spawn('claude', encoding='utf-8', timeout=timeout)

    # Set window size to avoid wrapping issues
    child.setwinsize(40, 160)

    # Buffer to accumulate all output we read manually
    log_capture = io.StringIO()

    effective_debug = debug and not silent

    def drain_output(duration: float):
        """Continuously read from the child for the given duration."""
        end_time = time.time() + duration
        while time.time() < end_time:
            try:
                chunk = child.read_nonblocking(size=4096, timeout=0.2)
                if chunk:
                    log_capture.write(chunk)
                    if effective_debug:
                        sys.stdout.write(chunk)
                        sys.stdout.flush()
            except pexpect.TIMEOUT:
                continue
            except pexpect.EOF:
                return True
        return False

    try:
        # Wait for ANY output first
        emit("Waiting for initial output...")
        time.sleep(2)  # Give Claude time to start up

        # Send the slash command
        emit(f"Sending command: {command}")
        child.send(command)  # Send without newline first
        time.sleep(0.5)  # Wait for autocomplete to appear

        emit("Pressing Enter to execute command...")
        child.send('\r')  # Press Enter to execute

        # Allow redraw-heavy UI to paint while we capture via read_nonblocking
        emit(f"Capturing output for {wait_time} seconds...")
        eof_reached = drain_output(wait_time)

        # Press Escape to exit the interactive view
        emit("Pressing Escape to dismiss dialog...")
        child.send('\x1b')  # ESC key
        if not eof_reached:
            eof_reached = drain_output(1)

        # Send /exit to close the TUI cleanly and get final output
        emit("Sending /exit to terminate session...")
        child.sendline('/exit')
        if not eof_reached:
            drain_output(1)

        output = log_capture.getvalue()

        if effective_debug:
            print("\nRaw captured output length:", len(output))

        cleaned_output = strip_ansi(output)

        # Wait for clean exit
        try:
            child.expect(pexpect.EOF, timeout=5)
        except:
            child.close(force=True)

        return cleaned_output or output

    except pexpect.TIMEOUT as e:
        print(f"\nTimeout: {e}", file=sys.stderr)
        if debug:
            print(f"Buffer before timeout: {child.before}", file=sys.stderr)
            print(f"Buffer after timeout: {child.after}", file=sys.stderr)
        child.close(force=True)
        return None

    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        child.close(force=True)
        return None

def write_error_log(path: str, message: str, silent: bool = False) -> None:
    """Persist an error message to the usage log so the statusline can surface it."""

    if not path:
        return

    try:
        with open(path, "w", encoding="utf-8") as error_file:
            error_file.write(f"ERROR: {message}\n")
    except OSError as exc:
        if not silent:
            print(f"Warning: failed to write usage log ({exc})", file=sys.stderr)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Capture Claude TUI slash command output")
    parser.add_argument("command", nargs="?", default="/usage",
                       help="Slash command to execute (default: /usage)")
    parser.add_argument("--debug", action="store_true",
                       help="Show all interactions")
    parser.add_argument("--timeout", type=int, default=30,
                       help="Timeout in seconds (default: 30)")
    parser.add_argument("--wait", type=int, default=5,
                       help="Seconds to wait after sending command (default: 5)")
    parser.add_argument("--usage-log", type=str, default="/tmp/usage.log",
                        help="File to write extracted usage info (default: /tmp/usage.log). Use empty string to skip.")
    parser.add_argument("--silent", action="store_true",
                        help="Suppress normal output; only emit errors")

    args = parser.parse_args()

    if args.debug and args.silent:
        parser.error("--debug and --silent cannot be used together")

    if PEXPECT_IMPORT_ERROR is not None:
        dependency_msg = "Missing dependency 'pexpect'. Install with 'pip install --user pexpect'."
        write_error_log(args.usage_log, dependency_msg, args.silent)
        if not args.silent:
            print(dependency_msg, file=sys.stderr)
        sys.exit(1)

    try:
        output = capture_slash_command(
            args.command,
            timeout=args.timeout,
            debug=args.debug,
            wait_time=args.wait,
            silent=args.silent,
        )
    except OSError as exc:
        error_message = f"Failed to spawn claude TUI ({exc})"
        if args.usage_log:
            write_error_log(args.usage_log, error_message, args.silent)
        if not args.silent:
            print(error_message, file=sys.stderr)
        sys.exit(1)

    if not output:
        error_message = "Failed to capture output or no output received"
        if args.usage_log:
            write_error_log(args.usage_log, error_message, args.silent)
        if not args.silent:
            print(error_message, file=sys.stderr)
        sys.exit(1)

    if not args.silent:
        print("\n" + "="*60)
        print(f"OUTPUT FROM '{args.command}':")
        print("="*60)
        print(output)
        print("="*60)

    usage_section = extract_usage_section(output)
    if args.usage_log:
        to_write = usage_section or output
        if usage_section is None:
            to_write = "ERROR: Could not locate usage section in output\n" + to_write
        try:
            with open(args.usage_log, 'w', encoding='utf-8') as usage_file:
                usage_file.write(to_write + '\n')
            if not args.silent:
                print(f"\nUsage details saved to: {args.usage_log}")
        except OSError as exc:
            print(f"\nWarning: Failed to write usage log ({exc})", file=sys.stderr)

    if usage_section:
        if not args.silent:
            print("\nCaptured Usage Section:")
            print("="*60)
            print(usage_section)
            print("="*60)
    else:
        warning_message = "Warning: Could not locate usage section in output"
        if not args.silent:
            print(f"\n{warning_message}", file=sys.stderr)

if __name__ == "__main__":
    main()
