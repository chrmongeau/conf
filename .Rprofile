set.seed(1)

# http://stackoverflow.com/questions/1189759/expert-r-users-whats-in-your-rprofile#comment12948814_2139002
.startup <- new.env()

# grep senza differenza maiuscole/minuscole
assign('grepi',
	function(p, x) {
		grep(p, x, ignore.case = TRUE, value = TRUE)
	}
, envir = .startup)

# grep senza differenza maiuscole/minuscole
assign('rotate_x_text',
	function() ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 0))
, envir = .startup)

# Se un numero è compreso in un intervallo o meno
assign('E',
	function(x, inf, sup, inc = TRUE) {
		ret <- FALSE
		if (inc) {
			if (x >= inf & x <= sup) ret <- TRUE
		} else {
			if (x > inf & x < sup) ret <- TRUE
		}
		return(ret)
	}
, envir = .startup)

# Converte stringhe in numeri: 201.342,32 => 201342.32
assign('str2num',
	function(x) {
		return(gsub(',', '.', gsub('\\.', '', as.character(x))))
	}
, envir = .startup)

# Download a page with RCurl and parse with htmlParse (from XML)
assign('download',
	function(url = '', file = '', verbose = TRUE, sleep.min = 1, sleep.max = 5) {
		library(XML)
		library(RCurl)
		if (url == '' | file == '') stop('AAHHH!!')

		dir_out <- dirname(file)

		if (dir_out != '.' && !dir.exists(dir_out)) {
			dir.create(dir_out, recursive = TRUE)
		}

		# Non ho trovato metodo per scrivere direttamente da XML quindi passo da RCurl
		x <- ''
		class(x) <- 'try-error'
		size <- 1 # Basta che sia != 0
		tmpfile <- paste(dir_out, 'xxx.html', sep = '/')
		while (class(x) == 'try-error' | size == 0) {
			if (verbose) print(paste('Downloading:', url))
			x <- try(getURL(url, useragent = 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:17.0) Gecko/20100101 Firefox/17.0'), silent = TRUE)
			if (verbose) print(class(x))
			if (class(x) != 'try-error') {
				cat(x, file = tmpfile)
				size <- file.info(tmpfile)$size
			}
			Sys.sleep(sample(sleep.min:sleep.max, 1))
		}
		cat(x, file = file)
		# XXX cosa succede quando "Errore in htmlParse(x) : File  does not exist" ???
		return(htmlParse(x))
	}
, envir = .startup)

assign('wd',
	function(path = NA) {
		if (missing(path)) {
			getwd()
		} else {
			setwd(path)
		}
	}
, envir = .startup)

assign('sort_mat',
	function(mat, by = 1) {
		arg <- list(mat[, by[1]])
		if (length(by) >= 2) {
			for (i in 2:length(by)) {
				arg[[i]] <- mat[, by[i]]
			}
		}
		mat <- mat[do.call('order', arg), ]
		return(mat)
	}
, envir = .startup)

assign('xy',
	function(x = NA, y = NA, by = NA, symbol = 16) {
		if (missing(x) | missing(y)) {
			stop('Series?')
		}
		if (missing(by)) {
			colors <- 'black'
			#stop('by?')
		} else {
			if (is.factor(by)) {
				colors <- topo.colors(length(levels(by)))[unlist(by)]
			} else {
				colors <- topo.colors(length(unique(by)))[by[order(by)]]
			}
		}
		plot(x, y, pch = symbol, col = colors)
	}
, envir = .startup)

assign('cuts',
	function(x, y = NA) {
		if (missing(y)) {
			return(cut(x, breaks = quantile(x), include.lowest = TRUE))
		} else {
			return(cut(x, breaks = quantile(x, probs = (1:(y - 1)) / y), include.lowest = TRUE))
		}
	}
, envir = .startup)

assign('hrefs',
	function(x = NA) {
		if (missing(x)) stop('URL?')
		require(RCurl) # XXX si potrebbe fare anche senza rcurl
		require(XML)
		doc <- htmlParse(getURL(x))
		a <- getNodeSet(doc, '//a')
		return(sapply(a, xmlGetAttr, 'href'))
	}
, envir = .startup)

assign('lib',
	function(libs) {
		for (i in libs) {
			if (require(i, character.only = TRUE)) {
				print(paste(i, 'caricato correttamente.'))
			} else {
				print(paste('Proviamo a installare', i))
				install.packages(i)
				if (require(i, character.only = TRUE)) {
					print(paste(i, 'installato e caricato correttamente.'))
				} else {
					stop(paste('Impossibile installare', i))
				}
			}
		}
	}
, envir = .startup)

assign('wb',
	function(x, file = paste(tempfile(), 'csv', sep = '.')) {
		write.csv(x, file); browseURL(file)
	}
, envir = .startup)

assign('wb2',
	function(x, file = paste(tempfile(), 'csv', sep = '.')) {
		write.csv2(x, file); browseURL(file)
	}
, envir = .startup)

# Attach packages, complaining loudly about any that are missing instead of
# failing silently or stopping startup. requireNamespace() is the check because
# it tests availability without attaching, so a missing package costs nothing.
assign('ensure',
	function(pkgs) {
		# Catch warnings rather than letting them fly. A warning raised inside
		# RStudio's sessionInit hook is deferred and then quietly dropped, so
		# "package 'x' was built under R version y" -- which is worth seeing,
		# it means the binary is newer than this R -- would vanish. Collect
		# them and print them ourselves below. Wraps both the availability
		# check and the attach, since either can be the one that warns.
		notes <- character(0)
		catching <- function(expr) withCallingHandlers(expr,
			warning = function(w) {
				notes <<- c(notes, trimws(conditionMessage(w)))
				invokeRestart('muffleWarning')
			})

		ok <- vapply(pkgs,
			function(p) catching(requireNamespace(p, quietly = TRUE)), logical(1))
		for (pkg in pkgs[ok]) {
			catching(suppressPackageStartupMessages(
				library(pkg, character.only = TRUE, warn.conflicts = FALSE)))
		}
		# Rgui on Windows prints escape codes literally, so colour only where it
		# will actually be rendered. RStudio handles ANSI; a plain terminal does
		# when stdout is a tty and not redirected.
		colour <- .Platform$GUI != 'Rgui' &&
			(Sys.getenv('RSTUDIO') == '1' || isatty(stdout()))
		# cat() to stdout, not message() to stderr. RStudio paints everything
		# arriving on stderr in its own colour, which wins over the escape codes
		# and turns the green line red. On stdout it honours them. Safe to use
		# stdout here because none of this runs outside interactive().
		say <- function(code, ...) {
			if (colour) cat('\033[', code, 'm', ..., '\033[0m\n', sep = '')
			else        cat(..., '\n', sep = '')
		}

		if (any(ok)) {
			# Report the version too: with data.table in particular, which
			# feature you get depends on it, and this is the cheapest place to
			# see what you are actually running.
			#
			# utils:: is required, not decoration. Called from .First() the
			# search path is only base and methods, so a bare packageVersion()
			# fails. It happens to work for a package like MASS that Depends on
			# utils, since library() attaches those -- which is exactly how this
			# escaped the first round of testing.
			vers <- vapply(pkgs[ok],
				function(p) as.character(utils::packageVersion(p)), character(1))
			say('1;32', 'LOADED   ', paste(pkgs[ok], vers, collapse = ', '))
		}
		# Plain yellow rather than the bold used for WARNING: related, but this
		# is information, not something you need to act on.
		for (n in notes) say('0;33', 'NOTE     ', n)
		if (any(!ok)) {
			bad <- pkgs[!ok]
			say('1;33', 'WARNING  not installed: ', paste(bad, collapse = ', '))
			say('1;33', '         install.packages(c(',
				paste0("'", bad, "'", collapse = ', '), '))')
		}
		invisible(pkgs[!ok])
	}
, envir = .startup)

############################ ALIAS ##################################
assign('table.prop', prop.table, envir = .startup)
assign('table.marg', margin.table, envir = .startup)

attach(.startup)

# Packages worth having in every interactive session. In .First() rather than at
# the top level of this file, so it runs after the workspace is restored.
#
# Careful: .First() still runs BEFORE .First.sys(), which is what attaches the
# default packages. search() in here is only .GlobalEnv, methods, Autoloads and
# base -- utils and stats are not up yet, so anything from them must be named
# explicitly, as ensure() does with utils::packageVersion.
#
# Gated on interactive() so Rscript runs stay quiet and fast, and so a script
# never silently inherits a package it did not ask for.
.First <- function() {
	if (!interactive()) return(invisible(NULL))
	pkgs <- c('data.table')
	if (Sys.getenv('RSTUDIO') == '1') {
		# RStudio has not finished wiring up its console this early, and drops
		# the escape codes emitted from here -- the text arrives, uncoloured.
		# This hook fires once the session is genuinely ready, where the same
		# codes render. Everywhere else .First() is early enough.
		setHook('rstudio.sessionInit',
			function(newSession) ensure(pkgs), action = 'append')
	} else {
		ensure(pkgs)
	}
}
