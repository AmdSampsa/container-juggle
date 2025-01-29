#!/bin/bash
gh pr create --draft \
--title "$1" --body "$1" \
--repo pytorch/pytorch \
--label "ciflow/inductor,ciflow/inductor-rocm,ciflow/periodic,ciflow/rocm,module:inductor,module:rocm,open source, rocm, topic:not user facing"
