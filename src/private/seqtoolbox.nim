# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

# Additional seq utilities

proc peek*[T](s: seq[T]): T {.inline.} =
  s[s.high]
