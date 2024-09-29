import sys

lines = open(sys.argv[1]).read().splitlines()
lines = sorted(lines, key=lambda s: int(s.split()[1], 16))
open(sys.argv[1], "w").write("\n".join(lines))