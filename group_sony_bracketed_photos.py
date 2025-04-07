from datetime import datetime
import argparse
from exiftool import ExifToolHelper
import glob
import os


ATTRIBUTES = [
    "SourceFile",
    "EXIF:Make",
    "EXIF:DateTimeOriginal",
    "EXIF:ExposureMode",
    "EXIF:ExposureCompensation",
    "MakerNotes:ReleaseMode",
    "MakerNotes:SequenceImageNumber",
    "MakerNotes:SequenceLength",
]


def main():
    arg_parser = argparse.ArgumentParser(description="Group Sony bracketed photos.")
    arg_parser.add_argument("--input", required=True, help="Path to the directory containing the Sony bracketed photos.")
    arg_parser.add_argument("--extension", default="ARW", help="Extension of the photos files.")
    arg_parser.add_argument("--output", required=True, help="Path to the output file listing the detected groups.")
    args = arg_parser.parse_args()

    image_files = [
        os.path.join(args.input, file)
        for file in os.listdir(args.input)
        if file.lower().endswith(f".{args.extension.lower()}")
    ]
    if not image_files:
        print(f"Error: No files found with extension {args.extension} in {args.input}.")
        exit(1)

    with ExifToolHelper() as et:
        metadata = et.get_metadata(image_files)

    filtered_metadata = [{key: item.get(key, None) for key in ATTRIBUTES} for item in metadata]
    filtered_metadata.sort(key=lambda x: x.get("SourceFile", ""))

    if any([True for item in filtered_metadata if item.get("EXIF:Make") != "SONY"]):
        print("Error: The script is designed to work with SONY cameras only at the moment.")
        exit(1)

    groups = []
    current_group = []

    for item in filtered_metadata:
        if (
            item.get("MakerNotes:ReleaseMode") == 5
            and item.get("EXIF:ExposureMode") == 2
            and item.get("MakerNotes:SequenceLength", 0) > 1
        ):
            seq_image_number = item["MakerNotes:SequenceImageNumber"]
            if seq_image_number == 1:
                # Start new group
                if current_group:
                    groups.append(current_group)
                current_group = [item]
            else:
                current_group.append(item)

    if current_group:
        groups.append(current_group)

    # Validate the groups
    for group in groups:
        timestamps = [datetime.strptime(item["EXIF:DateTimeOriginal"], "%Y:%m:%d %H:%M:%S") for item in group]
        for i in range(1, len(timestamps)):
            time_diff = abs((timestamps[i] - timestamps[i - 1]).total_seconds())
            if time_diff > 5:
                print(f"Warning: Time difference between {group[i - 1]['SourceFile']} and {group[i]['SourceFile']} exceeds 5 seconds.")

        sequence_length = [item["MakerNotes:SequenceLength"] for item in group]
        if len(set(sequence_length)) > 1:
            print(f"Warning: Inconsistent sequence lengths in group with SourceFile {group[0]['SourceFile']}.")
        sequence_length = sequence_length[0]

        if len(group) < sequence_length:
            print(f"Warning: Group with SourceFile {group[0]['SourceFile']} has fewer images ({len(group)}) than expected ({sequence_length}).")
        else:
            sequence_numbers = [item["MakerNotes:SequenceImageNumber"] for item in group]
            if sequence_numbers != list(range(1, sequence_length + 1)):
                print(f"Warning: Sequence numbers in group with SourceFile {group[0]['SourceFile']} are not monotonically increasing from 1 to {sequence_length}.")

        exposure_compensations = [item["EXIF:ExposureCompensation"] for item in group]
        if len(set(exposure_compensations)) != len(exposure_compensations):
            print(f"Warning: Exposure compensations in group with SourceFile {group[0]['SourceFile']} are not all unique.")

        if len(exposure_compensations) > 1 and len(group) == sequence_length:
            mean_rest = sum(exposure_compensations[1:]) / (len(exposure_compensations) - 1)
            if not abs(exposure_compensations[0] - mean_rest) < 1e-6:
                print(f"Warning: The first exposure compensation in group with SourceFile {group[0]['SourceFile']} is not the mean of the rest.")

    with open(args.output, "w", encoding="utf-8") as f:
        for group in groups:
            f.write("#group\n")
            for item in group:
                f.write(f"{item['SourceFile']}\n")

    print(f"Detected {len(groups)} groups and wrote the results to {args.output}.")


if __name__ == "__main__":
    main()
