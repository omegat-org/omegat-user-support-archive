# OmegaT User Support Archive

**[View The Archive](https://omegat.sourceforge.io/user-support-archive/)**

[OmegaT User Support](https://groups.yahoo.com/neo/groups/OmegaT/info) has been
hosted on Yahoo! Groups since March 2004.

Yahoo! has [announced](https://help.yahoo.com/kb/groups/SLN31010.html) that it
will severely downgrade its service starting October 28, 2019.

These tools were created in anticipation that Yahoo! will eventually completely
discontinue their Groups service.

# What is it?

This repository is mostly a [Makefile](https://www.gnu.org/software/make/)
implementing tools for archiving a Yahoo!  Groups group. From the repository
root run `make help` to list available targets:

```
usage: make [target]

Specify the group name with GROUP=foo (default: OmegaT)

Available targets:
  dump                     Download raw JSON for group
  validate                 Check dumped messages for errors
  view                     View a single dumped message as text
  clean                    Delete MBOX, Mailman data (does not delete ML dump)
  mbox                     Convert dump to MBOX format
  mbox-clean               Produce an MBOX cleaned by Mailman
  mailman-create           Create a new mailing list
  mailman-archive          Import MBOX into Mailman and build archives
  deploy                   Deploy Mailman archive to remote server
  submodules               Fetch submodules
  help                     Show this help text
```

# Usage

First you probably want to run `make dump` to dump all messages from your group
in JSON format.

Then, if you want to e.g. import your group into [GNU
Mailman](https://list.org/) you probably want to convert the archive to MBOX
format with `make mbox-clean`.

To generate archive HTML with GNU Mailman, run `make mailman-archive`.

To deploy the archive to a remote server via `rsync`, run `make deploy`.

# Requirements

- Python 3
- [jq](https://stedolan.github.io/jq/)
- [Docker](https://www.docker.com/) (for GNU Mailman)
  - [Direct download links](https://sourceforge.net/p/omegat/code/ci/1d1f384f0b420b1072190f35856a85d08fc63683/tree/doc_src/Readme.md)
