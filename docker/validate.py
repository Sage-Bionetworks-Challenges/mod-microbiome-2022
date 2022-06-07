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


def main():
    args = get_args()

    invalid_reasons = []

    pred = pd.read_csv(args.predictions_file)
    gold = pd.read_csv(args.goldstandard_file,
                       usecols=COLNAMES[args.task],
                       index_col="participant")

    expected_columns = COLNAMES[args.task]
    if set(pred.columns) != set(expected_columns):
        invalid_reasons.append(
            f"Invalid columns: {pred.columns.to_list()}. "
            f"Expecting: {expected_columns}"
        )

    duplicates = pred.duplicated(subset=['participant'])
    if duplicates.any():
        invalid_reasons.append(
            f"Found {duplicates.sum()} duplicate participant ID(s): "
            f"{pred[duplicates].participant.to_list()}"
        )

    pred.set_index('participant', inplace=True)
    missing_rows = gold.index.difference(pred.index)
    if missing_rows.any():
        invalid_reasons.append(
            f"Found {missing_rows.shape[0]} missing participant ID(s): "
            f"{missing_rows.to_list()}"
        )

    if not pred.iloc[:, 0].isin([0, 1]).all():
        invalid_reasons.append(
            f"'{pred.columns[0]}' column should only contain 0 and 1."
        )

    status = "INVALID" if invalid_reasons else "VALIDATED"
    invalid_reasons = "\n".join(invalid_reasons)

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
