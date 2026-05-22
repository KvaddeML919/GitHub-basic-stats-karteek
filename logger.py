"""Logging configuration for GitHub Analytics Service."""

import logging
import os
import sys
from typing import Optional


def _console_supports_color() -> bool:
    """Return True if ANSI colors are likely to render correctly."""
    if os.environ.get("NO_COLOR"):
        return False
    if not hasattr(sys.stdout, "isatty") or not sys.stdout.isatty():
        return False
    if sys.platform == "win32":
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined]
            for handle_id in (-11, -12):  # stdout, stderr
                handle = kernel32.GetStdHandle(handle_id)
                mode = ctypes.c_ulong()
                if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                    kernel32.SetConsoleMode(handle, mode.value | 0x0004)
            return True
        except (AttributeError, OSError):
            return False
    return True


class ColoredFormatter(logging.Formatter):
    """Colored formatter for console output."""

    # ANSI color codes
    COLORS = {
        'DEBUG': '\033[36m',    # Cyan
        'INFO': '\033[32m',     # Green
        'WARNING': '\033[33m',  # Yellow
        'ERROR': '\033[31m',    # Red
        'CRITICAL': '\033[35m', # Magenta
    }
    RESET = '\033[0m'

    def format(self, record):
        if _console_supports_color() and record.levelname in self.COLORS:
            record.levelname = f"{self.COLORS[record.levelname]}{record.levelname}{self.RESET}"
        return super().format(record)


def setup_logging(level: str = "INFO") -> logging.Logger:
    """Setup logging configuration.

    Args:
        level: Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)

    Returns:
        Configured logger instance
    """
    # Create main logger
    logger = logging.getLogger("github_analytics")
    logger.setLevel(getattr(logging, level.upper()))

    # Remove existing handlers to avoid duplication
    logger.handlers.clear()

    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, level.upper()))

    # Create formatter - simple format that matches current output style
    formatter = ColoredFormatter(
        fmt='%(message)s'  # Simple format to match current print behavior
    )
    console_handler.setFormatter(formatter)

    # Add handler to logger
    logger.addHandler(console_handler)

    # Prevent propagation to avoid duplicate messages
    logger.propagate = False

    return logger


def get_logger(name: Optional[str] = None) -> logging.Logger:
    """Get a logger instance.

    Args:
        name: Logger name, defaults to "github_analytics"

    Returns:
        Logger instance
    """
    if name is None:
        name = "github_analytics"
    return logging.getLogger(name)


# Create default logger instance
logger = setup_logging()


# Convenience functions that match the print statement behavior
def info(message: str) -> None:
    """Log info message (equivalent to print)."""
    logger.info(message)


def warning(message: str) -> None:
    """Log warning message."""
    logger.warning(message)


def error(message: str) -> None:
    """Log error message."""
    logger.error(message)


def debug(message: str) -> None:
    """Log debug message."""
    logger.debug(message)