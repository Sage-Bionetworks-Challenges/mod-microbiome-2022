#!/usr/bin/env python3

"""Validate Prediction File

Expected columns is dependent on Task number.
"""
import argparse
import json

import pandas as pd

COLNAMES = {
    1: ['participant', 'was_preterm'],
    2: ['participant', 'was_early_preterm']
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


def check_colnames(pred, task):
    expected_columns = COLNAMES[task]
    if set(pred.columns) != set(expected_columns):
        return (
            f"Invalid columns: {pred.columns.to_list()}. "
            f"Expecting: {expected_columns}"
        )
    return ""


def check_dups(pred):
    duplicates = pred.duplicated(subset=['participant'])
    if duplicates.any():
        return (
            f"Found {duplicates.sum()} duplicate participant ID(s): "
            f"{pred[duplicates].participant.to_list()}"
        )
    return ""


def check_missing(gold, pred):
    pred.set_index('participant', inplace=True)
    missing_rows = gold.index.difference(pred.index)
    if missing_rows.any():
        return (
            f"Found {missing_rows.shape[0]} missing participant ID(s): "
            f"{missing_rows.to_list()}"
        )
    return ""


def check_values(pred):
    if not pred.iloc[:, 0].isin([0, 1]).all():
        return f"'{pred.columns[0]}' column should only contain 0 and 1."
    return ""


def validate(gold_file, pred_file, task_number):
    errors = []

    gold = pd.read_csv(gold_file,
                       usecols=COLNAMES[task_number],
                       index_col="participant")
    pred = pd.read_csv(pred_file)

    errors.append(check_colnames(pred, task_number))
    errors.append(check_dups(pred))
    errors.append(check_missing(gold, pred))
    errors.append(check_values(pred))
    return errors


def main():
    args = get_args()

    invalid_reasons = validate(
        gold_file=args.goldstandard_file,
        pred_file=args.predictions_file,
        task_number=args.task
    )

    status = "INVALID" if invalid_reasons else "VALIDATED"
    invalid_reasons = "\n".join(filter(None, invalid_reasons))

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
