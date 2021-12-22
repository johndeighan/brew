# starbucks.test.coffee

import assert from 'assert'

import {slurp, mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {log} from '@jdeighan/coffee-utils/log'
import {starbucks} from '@jdeighan/starbucks'
import {loadEnv} from '@jdeighan/env'
import {brewCieloStr} from '@jdeighan/string-input/cielo'

process.env.DIR_ROOT = mydir(`import.meta.url`)
loadEnv()

# ---------------------------------------------------------------------------

class StarbucksTester extends UnitTester

	transformValue: (code) ->

		result = starbucks({content: code})
		return result.code

starbucksTester = new StarbucksTester()

# ---------------------------------------------------------------------------

starbucksTester.equal 26, """
		#starbucks webpage

		nav
		""", """
		<nav>
		</nav>
		"""

# ---------------------------------------------------------------------------

starbucksTester.equal 37, """
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
		""", """
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

starbucksTester.equal 79, """
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
		""", """
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

			import TopMenu from 'c:/Users/johnd/cielo/test/components/TopMenu.svelte';

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

starbucksTester.equal 174, """
		#starbucks component (hItem)

		# TopMenuShort.starbucks

		div.main
			#if hItem.url
				a href={hItem.url}
			#elsif hItem.lItems
				div.dropdown
			#else
				nav
		""", """
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

starbucksTester.equal 206, """
		#starbucks webpage

		TopMenu lItems={lItems}

		script
			lItems = [
				{ label: 'Home', url: '/'},
				{ label: 'Help', url: '/help'},
				]
		""", """
		<TopMenu lItems={lItems}>
		</TopMenu>
		<script>
			var lItems;

			import TopMenu from 'c:/Users/johnd/cielo/test/components/TopMenu.svelte';

			lItems = [
				{
					label: 'Home',
					url: '/'
					},
				{
					label: 'Help',
					url: '/help'
					}
				];
		</script>
		"""

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

class CieloTester extends UnitTester

	transformValue: (code) ->
		return brewCieloStr(code)

export cieloTester = new CieloTester()

# ---------------------------------------------------------------------------

cieloTester.equal 219, """
		import {undef, pass} from '@jdeighan/coffee-utils'
		import {slurp, barf} from '@jdeighan/coffee-utils/fs'

		try
			contents = slurp('myfile.txt')
		if (contents == undef)
			print "File does not exist"
		""", """
		import {undef, pass} from '@jdeighan/coffee-utils'
		import {slurp, barf} from '@jdeighan/coffee-utils/fs'

		try
			contents = slurp('myfile.txt')
		if (contents == undef)
			print "File does not exist"
		"""
