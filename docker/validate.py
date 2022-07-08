#!/usr/bin/env python3
"""Validate prediction file.

Prediction files between Task 1 and 2 are pretty much exactly
the same, with the exception of one column name, where:
    - Task 1: was_preterm
    - Task 2: was_early_preterm
"""

import argparse
import json

import pandas as pd
import numpy as np

COLS = {
    "1": {
        'participant': str,
        'was_preterm': np.int8,
        'probability': np.float64
    },
    "2": {
        'participant': str,
        'was_early_preterm': np.int8,
        'probability': np.float64
    }
}


def get_args():
    """Set up command-line interface and get arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--predictions_file",
                        type=str, required=True)
    parser.add_argument("-g", "--goldstandard_file",
                        type=str, required=True)
    parser.add_argument("-t", "--task", type=str, default="1")
    parser.add_argument("-o", "--output", type=str)
    return parser.parse_args()


def check_dups(pred):
    """Check for duplicate participant IDs."""
    duplicates = pred.duplicated(subset=['participant'])
    if duplicates.any():
        return (
            f"Found {duplicates.sum()} duplicate participant ID(s): "
            f"{pred[duplicates].participant.to_list()}"
        )
    return ""


def check_missing(gold, pred):
    """Check for missing participant IDs."""
    pred = pred.set_index('participant')
    missing_rows = gold.index.difference(pred.index)
    if missing_rows.any():
        return (
            f"Found {missing_rows.shape[0]} missing participant ID(s): "
            f"{missing_rows.to_list()}"
        )
    return ""


def check_values(pred, task):
    """Check that predictions column is binary."""
    if not pred.loc[:, pred.columns.str.contains('preterm')].isin([0, 1]).all().bool():
        return f"'{COLNAMES.get(task)[1]}' column should only contain 0 and 1."
    return ""


def validate(gold_file, pred_file, task_number):
    """Validate predictions file against goldstandard."""
    errors = []

    gold = pd.read_csv(gold_file,
                       index_col="participant")
    try:
        pred = pd.read_csv(pred_file,
                           usecols=COLS[task_number],
                           dtype=COLS[task_number],
                           float_precision='round_trip')
    except ValueError as err:
        errors.append(
            f"Invalid column names and/or types: {str(err)}. "
            f"Expecting: {str(COLS[task_number])}."
        )
    errors.append(check_missing(gold, pred))
    errors.append(check_values(pred, task_number))
    return errors


def main():
    """Main function."""
    args = get_args()

    invalid_reasons = validate(
        gold_file=args.goldstandard_file,
        pred_file=args.predictions_file,
        task_number=args.task
    )

    invalid_reasons = "\n".join(filter(None, invalid_reasons))
    status = "INVALID" if invalid_reasons else "VALIDATED"

    # truncate validation errors if >500 (character limit for sending email)
    if len(invalid_reasons) > 500:
        invalid_reasons = invalid_reasons[:496] + "..."
    res = json.dumps({
        "submission_status": status,
        "submission_errors": invalid_reasons
    })

    if args.output:
        with open(args.output, "w") as out:
            out.write(res)
    else:
        print(res)


if __name__ == "__main__":
    main()
