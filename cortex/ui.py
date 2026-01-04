"""
Cortex UI Module - Rich formatting with colors, boxes, and spinners.
Implements Issue #242 requirements.
"""

from __future__ import annotations

from contextlib import contextmanager

from rich.console import Console
from rich.panel import Panel
from rich.progress import BarColumn, Progress, SpinnerColumn, TextColumn, TimeElapsedColumn
from rich.status import Status
from rich.table import Table

console = Console()

# ============================================================================
# STATUS FUNCTIONS (replace cx_print patterns)


def success(message: str, details: str = ""):
    """Green success message with ✓"""
    badge = "[bold white on dark_cyan] CX [/bold white on dark_cyan]"
    console.print(f"{badge} [green]✓[/green] {message}")
    if details:
        console.print(f"    [dim]{details}[/dim]")


def error(message: str, details: str = ""):
    """Red error message with ✗"""
    badge = "[bold white on dark_cyan] CX [/bold white on dark_cyan]"
    console.print(f"{badge} [red]✗[/red] {message}")
    if details:
        console.print(f"    [red]{details}[/red]")


def warning(message: str, details: str = ""):
    """Yellow warning with ⚠"""
    badge = "[bold white on dark_cyan] CX [/bold white on dark_cyan]"
    console.print(f"{badge} [yellow]⚠[/yellow] {message}")
    if details:
        console.print(f"    [dim]{details}[/dim]")


def info(message: str):
    """Info message (same as cx_print)"""
    badge = "[bold white on dark_cyan] CX [/bold white on dark_cyan]"
    console.print(f"{badge} [dim]│[/dim] {message}")


def section(title: str):
    """Section header (same as cx_header)"""
    console.print()
    console.print(f"[bold cyan]━━━ {title} ━━━[/bold cyan]")
    console.print()


# ============================================================================
# SPINNER (for long operations)


@contextmanager
def spinner(message: str):
    """
    Context manager for showing spinner during long operations.

    Usage:
        with spinner("Installing packages..."):
            do_work()
    """
    status = console.status(f"[bold cyan]{message}[/bold cyan]", spinner="dots")
    status.start()
    try:
        yield status
    finally:
        status.stop()


# ============================================================================
# STATUS BOXES (Key information display)


def status_box(title: str, items: dict[str, str], border_color: str = "cyan"):
    """
    Display a boxed status (like ML Scheduler example from issue)

    Example:
        status_box(
            "CORTEX ML SCHEDULER",
            {
                "Status": "● Active",
                "Uptime": "0.5 seconds"
            }
        )
    """
    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Key", style="dim", width=15)
    table.add_column("Value", style="white")

    for key, value in items.items():
        table.add_row(f"{key}:", value)

    panel = Panel(
        table,
        title=f"[bold]{title}[/bold]",
        border_style=border_color,
        padding=(1, 2),
        expand=False,
        width=70,
    )

    console.print(panel)


def summary_box(title: str, items: list[str], success: bool = True):
    """
    Summary box for installation completion

    Example:
        summary_box(
            "INSTALLATION COMPLETE",
            ["nginx 1.18.0", "docker 24.0.5"],
            success=True
        )
    """
    color = "green" if success else "red"
    icon = "✓" if success else "✗"

    content = f"[{color}]{icon}[/{color}] {title}\n\n"
    for item in items:
        content += f"  • {item}\n"

    panel = Panel(content, border_style=color, padding=(1, 2))

    console.print(panel)
