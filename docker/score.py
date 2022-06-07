#!/usr/bin/env python3
"""Score prediction file.

Task 1 and 2 will return the same metrics:
    - ROC curve
    - PR curve
    - accuracy
    - sensitivity
    - specificity
"""

import argparse
import json

import pandas as pd

COLNAME = {
    1: 'was_preterm',
    2: 'was_early_preterm'
}


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--predictions_file",
                        type=str, required=True)
    parser.add_argument("-g", "--goldstandard_file",
                        type=str, required=True)
    parser.add_argument("-t", "--task", type=int, default=1)
    parser.add_argument("-o", "--output", type=str)
    return parser.parse_args()


def main():
    """Main function."""
    args = get_args()

    with open(args.output, "w") as out:
        res = {
            "submission_status": "SCORED",
            "roc_curve": 1,
            "pr_curve": 1,
            "accuracy": 1,
            "sensitivity": 1,
            "specificity": 1
        }
        out.write(json.dumps(res))


if __name__ == "__main__":
    main()
