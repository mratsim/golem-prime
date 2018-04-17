# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

template debug_only*(body: untyped): untyped =
  when compileOption("boundChecks"):
    body

template debug*(title: string) =
  debugecho title & $point
  for neighbor in point.neighbors:
    debugecho "Neighbor: " & (if self.board[neighbor] == Border: $Border else: $neighbor) &
              ", Liberties: " & $self.group(neighbor).nb_pseudo_libs
