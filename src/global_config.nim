# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

const Max_Board_Size* = 19
  # 38 is the max board supported on KGS.
  # This impacts the binary size and cache usage.
  # It is used to precompute the hashes of board positions
