# Makefile for MongoDB Sphinx documentation

# You can set these variables from the command line.
SPHINXOPTS    = -c ./
SPHINXBUILD   = sphinx-build
PAPER	      =

# change this to reflect the location of the public repo
publication-output = ../public-docs

# change this to reflect the branch that "manual/" will point to
manual-branch = master
# intuit the current branch
current-branch := $(shell git symbolic-ref HEAD 2>/dev/null | cut -d "/" -f "3" )

# Build directory tweaking.
CURRENTBUILD = $(publication-output)/$(current-branch)
BUILDDIR = build

# Fixing `sed` for OS X
UNAME := $(shell uname)

ifeq ($(UNAME), Linux)
SED_ARGS = -i -r
endif
ifeq ($(UNAME), Darwin)
SED_ARGS = -i "" -E
endif

# Internal variables.
PAPEROPT_a4 = -D latex_paper_size=a4
PAPEROPT_letter = -D latex_paper_size=letter
ALLSPHINXOPTS = -q -d $(BUILDDIR)/doctrees $(PAPEROPT_$(PAPER)) $(SPHINXOPTS) source
DRAFTSPHINXOPTS = -q -d $(BUILDDIR)/draft-doctrees $(PAPEROPT_$(PAPER)) $(SPHINXOPTS) draft

.PHONY: publish help clean push-dc1 push-dc2

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "	 html		to make standalone HTML files"
	@echo "	 dirhtml	to make HTML files named index.html in directories"
	@echo "	 singlehtml	to make a single large HTML file"
	@echo "	 epub		to make an epub"
	@echo "	 latex		to make LaTeX files, you can set PAPER=a4 or PAPER=letter"
	@echo "	 man		to make manual pages"
	@echo "	 changes	to make an overview of all changed/added/deprecated items"
	@echo
	@echo "MongoDB Manual Specific Targets."
	@echo "	 publish	runs publication process and then deploys the build to $(publication-output)"
	@echo "	 push		runs publication process and pushes to docs site to production."
	@echo "	 draft		builds a 'draft' build for pre-publication testing ."
	@echo "	 pdfs		generates pdfs more efficently than latexpdf."
	@echo
	@echo "See 'meta.build.rst' for more information."

#
# Meta targets that control the build and publication process.
#

push:publish
	@echo "Copying the new build to the web servers."
	$(MAKE) -j2 MODE='push' push-dc1 push-dc2

publish:
	@echo "Running the publication and migration routine..."
	$(MAKE) -j1 deploy-stage-one
	$(MAKE) -j setup deploy-stage-two deploy-stage-three
	@echo "Publication succeessfully deployed to '$(publication-output)'."
	@echo

#
# Targets for pushing the new build to the web servers.
#

ifeq ($(MODE),push)
push-dc1:
	rsync -arz ../public-docs/ www@www-c1.10gen.cc:/data/sites/docs
push-dc2:
	rsync -arz ../public-docs/ www@www-c2.10gen.cc:/data/sites/docs
endif

######################################################################
#
# Targets that should/need only be accessed in publication
#
######################################################################


# Deployment targets to kick off the rest of the build process. Only
# access these targets through the ``publish`` target.
.PHONY: setup deploy-stage-one deploy-stage-two

setup:
	mkdir -p $(BUILDDIR)/{dirhtml,singlehtml,html,epub,latex} $(CURRENTBUILD)/single
deploy-stage-one:source/about.txt $(BUILDDIR)/html
deploy-stage-two:$(CURRENTBUILD) $(CURRENTBUILD)/release.txt $(CURRENTBUILD)/MongoDB-Manual.pdf $(CURRENTBUILD)/MongoDB-Manual.epub
deploy-stage-three:$(CURRENTBUILD)/single $(CURRENTBUILD)/single/search.html $(CURRENTBUILD)/single/genindex.html $(CURRENTBUILD)/single/index.html

# Establish dependencies for building the manual. Also helpful in
# ordering the build itself.

$(BUILDDIR)/epub/MongoDB.epub:epub
$(BUILDDIR)/latex/MongoDB.tex:latex
$(BUILDDIR)/latex/MongoDB.pdf:$(BUILDDIR)/latex/MongoDB.tex

$(BUILDDIR)/singlehtml/contents.html:$(BUILDDIR)/singlehtml
$(BUILDDIR)/dirhtml/search/index.html:$(BUILDDIR)/dirhtml
$(BUILDDIR)/html/genindex.html:$(BUILDDIR)/html

$(BUILDDIR)/dirhtml:dirhtml
	touch $@
$(BUILDDIR)/html:html
	touch $@
$(BUILDDIR)/singlehtml:singlehtml
	touch $@

# Build and migrate the epub and PDF.
$(CURRENTBUILD)/MongoDB-Manual-$(current-branch).pdf:$(BUILDDIR)/latex/MongoDB.pdf
	cp $< $@
$(CURRENTBUILD)/MongoDB-Manual-$(current-branch).epub:$(BUILDDIR)/epub/MongoDB.epub
	cp $< $@
MongoDB-Manual.pdf:$(CURRENTBUILD)/MongoDB-Manual-$(current-branch).pdf
	ln -s -f $(notdir $<) $@
MongoDB-Manual.epub:$(CURRENTBUILD)/MongoDB-Manual-$(current-branch).epub
	ln -s -f $(notdir $<) $@
$(CURRENTBUILD)/MongoDB-Manual.epub:./MongoDB-Manual.epub
	mv $< $@
$(CURRENTBUILD)/MongoDB-Manual.pdf:./MongoDB-Manual.pdf
	mv $< $@

# Build and migrate the HTML components of the build.
$(CURRENTBUILD):$(BUILDDIR)/dirhtml
	cp -R $</* $@/
$(CURRENTBUILD)/single:$(BUILDDIR)/singlehtml
	cp -R $</* $@

# fixup the single html page:
$(CURRENTBUILD)/single/search.html:$(BUILDDIR)/dirhtml/search/index.html
	cp $< $@
$(CURRENTBUILD)/single/genindex.html:$(BUILDDIR)/html/genindex.html
	cp $< $@
	sed $(SED_ARGS) -e 's@(<dt><a href=").*html#@\1./#@' $@
$(CURRENTBUILD)/single/index.html:$(BUILDDIR)/singlehtml/contents.html
	cp $< $@
	sed $(SED_ARGS) -e 's/href="contents.html/href="index.html/g' $@

# Deployment related work for the non-Sphinx aspects of the build.
$(CURRENTBUILD)/release.txt:$(publication-output)/manual
	git rev-parse --verify HEAD >|$@
$(publication-output):
	mkdir -p $@
$(publication-output)/manual:manual
	mv $< $@
	-rm -f $(CURRENTBUILD)/manual
$(publication-output)/index.html:themes/docs.mongodb.org/index.html
	cp $< $@
manual:$(CURRENTBUILD)
	ln -f -s $(manual-branch) $@
source/about.txt:
	touch source/about.txt

# Clean up/removal targets.
clean:
	-rm -rf $(BUILDDIR)/*

######################################################################
#
# Default HTML Sphinx build targets
#
######################################################################

.PHONY: html dirhtml singlehtml epub
html:
	$(SPHINXBUILD) -b html $(ALLSPHINXOPTS) $(BUILDDIR)/html
	@echo "[HTML] build complete."
dirhtml:
	$(SPHINXBUILD) -b dirhtml $(ALLSPHINXOPTS) $(BUILDDIR)/dirhtml
	@echo "[DIR-HTML] build complete."
singlehtml:
	$(SPHINXBUILD) -b singlehtml $(ALLSPHINXOPTS) $(BUILDDIR)/singlehtml
	@echo "[SINGLE-HTML] build complete."
epub:
	$(SPHINXBUILD) -b epub $(ALLSPHINXOPTS) $(BUILDDIR)/epub
	@echo "[EPUB] Build complete."

######################################################################
#
# Targets for manpages
#
######################################################################

# helpers for compressing man pages
UNCOMPRESSED_MAN := $(wildcard $(BUILDDIR)/man/*.1)
COMPRESSED_MAN := $(subst .1,.1.gz,$(UNCOMPRESSED_MAN))

man:
	$(SPHINXBUILD) -b man $(ALLSPHINXOPTS) $(BUILDDIR)/man
	@echo "[MAN] build complete."

# Targets to build compressed man pages.
build-man: man $(COMPRESSED_MAN)
compress-man: $(COMPRESSED_MAN)
$(BUILDDIR)/man/%.1.gz: $(BUILDDIR)/man/%.1
	gzip $< -c > $@

######################################################################
#
# Build Targets for Draft Build.
#
######################################################################

.PHONY: aspirational aspiration draft draft-pdf draft-pdfs
aspiration:draft
aspirational:draft
draft:
	$(SPHINXBUILD) -b html $(DRAFTSPHINXOPTS) $(BUILDDIR)/draft
	@echo "[DRAFT] HTML build finished."
draft-latex:
	$(SPHINXBUILD) -b latex $(DRAFTSPHINXOPTS) $(BUILDDIR)/draft-latex
	@echo "[DRAFT] LaTeX build finished."
draft-pdf:$(subst .tex,.pdf,$(wildcard $(BUILDDIR)/draft-latex/*.tex))
draft-pdfs:draft-latex draft-pdf


##########################################################################
#
# Default Sphinx targets that are totally unused, but around just in case.
#
##########################################################################

.PHONY: changes linkcheck json doctest
json:
	$(SPHINXBUILD) -b json $(ALLSPHINXOPTS) $(BUILDDIR)/json
	@echo "[JSON] build finished."
changes:
	$(SPHINXBUILD) -b changes $(ALLSPHINXOPTS) $(BUILDDIR)/changes
	@echo "[CHANGES] build finished."
linkcheck:
	$(SPHINXBUILD) -b linkcheck $(ALLSPHINXOPTS) $(BUILDDIR)/linkcheck
	@echo "[LINK] Link check complete. See $(BUILDDIR)/linkcheck/output.txt."
doctest:
	$(SPHINXBUILD) -b doctest $(ALLSPHINXOPTS) $(BUILDDIR)/doctest
	@echo "[TEST] doctest complete."

######################################################################
#
# PDF Build System.
#
######################################################################

.PHONY:pdfs latex latexpdf

latex:
	$(SPHINXBUILD) -b latex $(ALLSPHINXOPTS) $(BUILDDIR)/latex
	@echo "[TeX] Build complete."
latexpdf:latex
	$(MAKE) -C $(BUILDDIR)/latex all-pdf
	@echo "[PDF] build complete."

LATEX_CORRECTION = "s/(index|bfcode)\{(.*!*)*--(.*)\}/\1\{\2-\{-\}\3\}/g"

$(BUILDDIR)/latex/%.tex:
	sed $(SED_ARGS) -e $(LATEX_CORRECTION) -e $(LATEX_CORRECTION) $@

pdfs:$(subst .tex,.pdf,$(wildcard $(BUILDDIR)/latex/*.tex))

PDFLATEXCOMMAND = TEXINPUTS=".:$(BUILDDIR)/latex/:" pdflatex --interaction batchmode --output-directory $(BUILDDIR)/latex/

%.pdf:%.tex
	@$(PDFLATEXCOMMAND) $(LATEXOPTS) '$<'
	@echo "[PDF]: (1/4) pdflatex $<"
	@-makeindex -s $(BUILDDIR)/latex/python.ist '$(basename $<).idx'
	@echo "[PDF]: (2/4) Indexing: $(basename $<).idx"
	@$(PDFLATEXCOMMAND) $(LATEXOPTS) '$<'
	@echo "[PDF]: (3/4) pdflatex $<"
	@$(PDFLATEXCOMMAND) $(LATEXOPTS) '$<'
	@echo "[PDF]: (4/4) pdflatex $<"

##########################################################################
#
# Archiving $(publication-output) for cleaner full rebuilds
#
##########################################################################

ARCHIVE_DATE := $(shell date +%s)
archive:$(publication-output).$(ARCHIVE_DATE).tar.gz
	@echo [archive] $<
$(publication-output).$(ARCHIVE_DATE).tar.gz:$(publication-output)
	tar -czvf $@ $<
