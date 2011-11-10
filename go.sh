#!/bin/sh
(cd src/ && cake build) && ./chromeless/chromeless src
