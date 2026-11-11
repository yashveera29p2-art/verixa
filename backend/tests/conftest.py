import os
import sys
from pathlib import Path

# Tests run without Firebase; the auth test switches it back on explicitly.
os.environ.setdefault("VERIXA_AUTH_MODE", "disabled")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
