---
name: review
description: review the codebase
---
Do an in-depth review of the the entire codebase. Find any logic bugs, unfinished features, and failure points.

Rank issues by the following severity scale. 1 is most severe and 6 is least severe:

1. Inconsistencies of data structures and processing accross frontend, agent workflow, and experiment runner branches of the codebase
2. Subtle logic bugs that lead to unexpected behavior
3. Failure points that crash the program
5. Dead or redundant code
5. Bottlenecks that signifcantly impact performance
6. Any other issues you think are important

You should not write any code, but you should propose fixes to the issues you found.
