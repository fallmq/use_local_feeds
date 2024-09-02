#!/bin/bash

# Define the file path
FILE="feeds.conf.default"
TEMP_FILE="temp.conf"

#Update MTK Feeds
if [[ $PROFILE == *"mtk"* ]]; then
    echo -e "\033[33mMTK Feeds update.\033[0m"
    rm -f ${PWD}/feeds.conf.default
    cp ${PWD}/feeds_mtk ${PWD}/feeds.conf.default
fi

# Check if the file exists
if [ ! -f "$FILE" ]; then
    echo "File not found!"
    exit 1
fi

# Create a temporary file
touch $TEMP_FILE

# Read each line from the file
while IFS= read -r line; do
    # Skip lines that start with #
    if [[ $line =~ ^# ]]; then
        echo "$line" >> $TEMP_FILE
        continue
    fi

    if [[ $line =~ ^src-git ]]; then
        # Comment the original line and write to temp file
        echo "#$line" >> $TEMP_FILE
        # Extract the name
        name=$(echo $line | cut -d ' ' -f 2)
        # Extract the commit hash after the last '^'
        commit_hash=$(echo $line | rev | cut -d '^' -f 1 | rev)
        # Generate the corresponding src-link line
        echo "src-link $name ../../feeds/openwrt_$name" >> $TEMP_FILE
        # Execute git checkout command
        echo -e "\033[33mCheckout \"feeds_openwrt_$name\" to \"$commit_hash\"\033[0m"
        (cd "../feeds/openwrt_$name" && git checkout $commit_hash)
    else
        # Write other lines as they are to the temp file
        echo "$line" >> $TEMP_FILE
    fi
done < "$FILE"

# Move the temporary file to original file
mv $TEMP_FILE $FILE

# Remove the temporary file if it still exists
[ -f "$TEMP_FILE" ] && rm $TEMP_FILE

if [[ $PROFILE == *"mtk"* ]]; then
    cp ${PWD}/feeds.conf.default ${PWD}/feeds_mtk
fi

# Print completion message
echo -e "\033[32mFile has been updated successfully.\033[0m"
