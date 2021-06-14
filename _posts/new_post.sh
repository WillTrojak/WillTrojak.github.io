#!/bin/zsh
emulate -LR zsh # reset zsh options
export PATH=/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

TODAY=$(date +"%Y-%m-%d")
NOW=$(date +"%Y-%m-%d %X %z")

HEADLINE=$1
HEADLINE="${HEADLINE/ /-}"
FILENAME="$TODAY-$HEADLINE.md"

NEW_POST="---"
NEW_POST="$NEW_POST\nlayout: post"
NEW_POST="$NEW_POST\ntitle: \"$2\""
NEW_POST="$NEW_POST\ndate: $NOW"
NEW_POST="$NEW_POST\ncategories: $3 $4 $5"
NEW_POST="$NEW_POST\n---\n\nADD BODY\n"
echo $NEW_POST >> $FILENAME
echo "Made new post in: $FILENAME"

