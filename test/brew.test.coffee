# brew.test.coffee

import {strict as assert} from 'assert'

import {slurp, mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'

testDir = mydir(`import.meta.url`)

# ---------------------------------------------------------------------------

class BrewTester extends UnitTester

	transformValue: (filename) ->

		return slurp(mkpath(testDir, filename))

export tester = new BrewTester()

# ---------------------------------------------------------------------------

###
	#starbucks webpage

	nav
###

tester.equal 27, 'nav.svelte', """
		<nav>
		</nav>
		"""

# ---------------------------------------------------------------------------

###
	#starbucks webpage

	nav lItems={<<<}
		---
		-
			label: Home
			url: /
		-
			label: Help
			lItems:
				-
					label: About
					url: /about
				-
					label: Contact
					url: /contact
###

tester.equal 53, 'heredoc.svelte', """
		<nav lItems={__anonVar0}>
		</nav>
		<script>
			import {taml} from '@jdeighan/string-input/taml'
			var __anonVar0;

			__anonVar0 = taml(`---
			-
					label: Home
					url: /
			-
					label: Help
					lItems:
							-
									label: About
									url: /about
							-
									label: Contact
									url: /contact`);
		</script>
		"""

# ---------------------------------------------------------------------------

###
	#starbucks webpage

	nav
		TopMenu lItems={<<<}
			---
			-
				label: Home
				url: /
			-
				label: Help
				lItems:
					-
						label: About
						url: /about
					-
						label: Contact
						url: /contact

	main
		slot

	footer web page by {{author}}

	style

		nav
			grid-area: top
			text-align: center

		main
			grid-area: middle
			overflow: auto
			margin: 5px

		footer
			grid-area: bottom
			text-align: center
			background-color: yellow
###

tester.equal 118, 'layout.svelte', """
		<nav>
			<TopMenu lItems={__anonVar0}>
			</TopMenu>
		</nav>
		<main>
			<slot>
			</slot>
		</main>
		<footer>
			web page by
		</footer>
		<script>
			import {taml} from '@jdeighan/string-input/taml'
			var __anonVar0;

			import TopMenu from 'C:/Users/johnd/cielo/test/components/TopMenu.svelte';

			__anonVar0 = taml(`---
			-
					label: Home
					url: /
			-
					label: Help
					lItems:
							-
									label: About
									url: /about
							-
									label: Contact
									url: /contact`);
		</script>
		<style>
			nav {
					grid-area: top;
					text-align: center;
			}

			main {
					grid-area: middle;
					overflow: auto;
					margin: 5px;
			}

			footer {
					grid-area: bottom;
					text-align: center;
					background-color: yellow;
			}
		</style>
		"""

# ---------------------------------------------------------------------------

###
	#starbucks component (hItem)

	# TopMenuShort.starbucks

	div.main
		#if hItem.url
			a href={hItem.url}
		#elsif hItem.lItems
			div.dropdown
		#else
			nav
###

tester.equal 189, 'TopMenuShort.svelte', """
		<div class="main">
			{#if hItem.url}
				<a href={hItem.url}>
				</a>
			{:else if hItem.lItems}
				<div class="dropdown">
				</div>
			{:else}
				<nav>
				</nav>
			{/if}
		</div>
		<script>
			export var hItem = undef;
		</script>
		"""

# ---------------------------------------------------------------------------
