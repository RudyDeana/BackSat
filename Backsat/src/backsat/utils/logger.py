import logging
from rich.logging import RichHandler
from rich.console import Console

console = Console()

def get_logger(name):
    logging.basicConfig(
        level="INFO",
        format="%(message)s",
        datefmt="[%X]",
        handlers=[RichHandler(console=console, rich_tracebacks=True)]
    )
    
    logger = logging.getLogger(name)
    return logger 