# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import ./datatypes

proc neighbors*[N: static[int16]](idx: Point[N]): array[4, Point[N]] {.inline.}=
  [idx-1, idx+1, idx - (N+2), idx + (N+2)]
