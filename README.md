[![Project logo](https://github.com/Tw1ddle/word-reactor/blob/master/screenshots/wordreactor_logo.png "Markov Procedural Word Reactor Simulation logo")](https://tw1ddle.github.io/word-reactor/)

[![License](https://licensebuttons.net/l/by-nc/4.0/80x15.png)](https://github.com/Tw1ddle/word-reactor/blob/master/LICENSE)
[![Build Status Badge](https://ci.appveyor.com/api/projects/status/github/Tw1ddle/word-reactor)](https://ci.appveyor.com/project/Tw1ddle/word-reactor)

**Word Reactor** is a Markov chain-based word generator running inside a physics simulation. Run it [in your browser](https://tw1ddle.github.io/word-reactor/).

Demonstrates the [Markov Namegen](https://www.samcodes.co.uk/project/markov-namegen/) name generator and [Haxe](https://haxe.org/) library.

## Usage ##

Open it [in the browser](https://tw1ddle.github.io/word-reactor/) and generate words. Click or tap empty spaces to spawn stream of words for different topics. Drag the balls around to mix things up, and collide the balls with "topic" words in them to create new words:

[![Screenshot](https://github.com/Tw1ddle/word-reactor/blob/master/screenshots/screenshot2.gif?raw=true "Word Reactor spawning new words")](https://tw1ddle.github.io/word-reactor/)

## Install ##

Get Markov Namegen on [GitHub](https://github.com/Tw1ddle/MarkovNameGenerator) or through [haxelib](https://lib.haxe.org/p/markov-namegen/), and read the [documentation here](https://tw1ddle.github.io/MarkovNameGenerator/).

Include it in your ```.hxml```
```
-lib markov-namegen
```

Or add it to your ```Project.xml```:
```
<haxelib name="markov-namegen" />
```

## How It Works ##

The [markov-namegen haxelib](https://lib.haxe.org/p/markov-namegen) uses [Markov chains](https://en.wikipedia.org/wiki/Markov_chain) to generate random words. Given a set of words as [training data](https://github.com/Tw1ddle/MarkovNameGenerator/tree/master/embed), the library calculates the conditional probability of a letter coming up after a sequence of letters chosen so far. It looks back up to "n" characters, where "n" is the order of the model.

The physics simulation is made using [Nape](https://github.com/HaxeFlixel/nape-haxe4), a 2D rigid body physics engine for Haxe. When balls containing topic words collide, balls are added to the simulation that contain new words generated using the training data for those topics.

The visualization is rendered using HTML5 with text, images and canvas elements, using absolute positioning for the balls. This is all kept in sync with the Nape physics simulation in a requestAnimationFrame loop.

## Notes ##
* Inspired by the [ball pool](https://mrdoob.com/projects/chromeexperiments/ball-pool/) experiment by [Ricardo Cabello](https://twitter.com/mrdoob) and sample projects from [Nape](https://github.com/deltaluca/nape) by [Luca Deltodesco](https://github.com/deltaluca).
* Many of the concepts used for the word generator were suggested in [this article](https://www.roguebasin.com/index.php?title=Names_from_a_high_order_Markov_Process_and_a_simplified_Katz_back-off_scheme) by [Jeffrey Lund](https://github.com/jlund3).
* If you have any questions or suggestions then [get in touch](https://samcodes.co.uk/contact) or open an issue.

## License ##
The demo code is licensed under CC BY-NC. The [haxelib library](https://lib.haxe.org/p/markov-namegen/) itself is MIT licensed. Training data was compiled from sites like Wikipedia and census data sources.