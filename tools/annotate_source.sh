#!/usr/bin/env bash

PROFILE_FILE="$1"

# 1. Find the highest number (strips "profiling_" and ".jl")
#    If no files exist, "head" returns nothing.
last_num=$(ls profiling_*.jl 2>/dev/null | sed -E 's/profiling_([0-9]+)\.jl/\1/' | sort -rn | head -n 1)

# 2. Set default to -1 if no files exist (so -1 + 1 = 0)
if [ -z "$last_num" ]; then
    last_num=-1
fi

# 3. Increment the number
next_num=$((last_num + 1))

# 4. Generate filename with 00, 01 padding using printf
#    %02d means: "Format as decimal, at least 2 digits, pad with zero"
printf -v new_filename "profiling_%02d.jl" "$next_num"

# 5. Extract metadata from the profile log
# Get the full path to the source script 
SCRIPT_PATH=$(grep "Script path:" "$PROFILE_FILE" | awk '{print $3}')
# Get the delay value (e.g., 0.001) 
DELAY=$(grep "Delay:" "$PROFILE_FILE" | awk '{print $2}')
# Get the filename (e.g., NewCircleCheck.jl) to match against the profile table
SCRIPT_BASENAME=$(basename "$SCRIPT_PATH")

# Verify the source file exists before proceeding
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Source file '$SCRIPT_PATH' could not be found."
    exit 1
fi

# 6. Process the files using awk
# We pass the profile data path, the delay, and the script name as variables.
# We then read the actual Source Code file as the main input to awk.
awk -v profile="$PROFILE_FILE" \
    -v delay="$DELAY" \
    -v target="$SCRIPT_BASENAME" '
    BEGIN {
        # PASS 1: Read the profile file to map Line Numbers -> Time
        while ((getline < profile) > 0) {
            # Field $3 is the File path (e.g., @Diffusion.../NewCircleCheck.jl)
            # Field $4 is the Line number
            # Field $1 is the Count
            
            # Check if this row belongs to our target script and has a valid count
            if ($3 ~ target && $1 ~ /^[0-9]+$/) {
                # Calculate time = Count * Delay
                time = $1 * delay
                # Store it in a map: times[line_number] = time
                times[$4] = time
            }
        }
        close(profile)
    }

    {
        # PASS 2: Process the actual source code (FNR is the line number of the source file)
        line_content = $0
        line_num = FNR
        
        # Check if we have a recorded time for this specific line number
        if (line_num in times) {
            # Calculate how much padding is needed to reach column 80
            line_len = length(line_content)
            
            if (line_len < 79) {
                # If short enough, pad with spaces up to column 80
                padding = sprintf("%*s", 79 - line_len, "")
                printf "%s%s# Time: %s\n", line_content, padding, times[line_num]
            } else {
                # If line is already long (>79 chars), just add one space
                printf "%s # Time: %s\n", line_content, times[line_num]
            }
        } else {
            # No timing data for this line, just print it as is
            print line_content
        }
    }
' "$SCRIPT_PATH" > "$new_filename"

echo "Printed to ${new_filename}."
