import sys
import signal
import os
from XSPython import DUTSimTop, difftest as df, xsp
from XSPython.XSPdb import *

def handle_sigint(signum, frame):
    print("\nReceived SIGINT, exit.")
    sys.exit(0)
signal.signal(signal.SIGINT, handle_sigint)

def test_sim_top():
    bin_file = sys.argv[1] if len(sys.argv) > 1 else None
    if bin_file is None:
        print("Usage: python test.py <bin_file>")
        print("Use ready-to-run/microbench.bin for minimal debug test.")
        bin_file = "ready-to-run/microbench.bin"
    if not os.path.exists(bin_file):
        print(f"File {bin_file} does not exist.")
        sys.exit(1)
    if not os.path.isfile(bin_file):
        print(f"{bin_file} is not a file.")
        sys.exit(1)
    dut = DUTSimTop()
    XSPdb(dut, df, xsp, bin_file).set_trace()
    while True:
        dut.Step(10000000)

if __name__ == "__main__":
    test_sim_top()
