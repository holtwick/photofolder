# PhotoFolder

Command line tool for organizing images.

> Download precompiled binary: photofolder.zip

```
Usage: photofolder <options> [inputfile ...]

  -?  --help                 Display this usage information.
  -v  --verbose              Print verbose messages.
  -r  --recursive            Recurse into input folders.
  -o  --destination=folder   Target folder.
  -n  --name=text            Add name to file name.
  -c  --copy                 Copy instead of move.
  -p  --progress             Show progress.
  -s  --days=number          Maximal age in days.
      --dry                  Dry run.
      --checksum             Identify duplicates by SHA1 of content.
      --size                 Identify duplicates by file size in bytes.
      --dimensions           Add dimensions to file name.
      --maker                Add maker/ camera model to file name.
      --year-folder          Subfolders per year.
      --month-folder         Subfolders per year and month.
      --optimize             Convert to JPG and minimize size.
      --smart-copy           Most options for unique incremental copy.
      --smart-move           Most options for unique incremental move.
      --version              Version info.
```

