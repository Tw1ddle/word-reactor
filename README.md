[![Project logo](https://github.com/Tw1ddle/word-reactor/blob/master/screenshots/wordreactor_logo.png "Markov Procedural Word Reactor Simulation logo")](http://www.samcodes.co.uk/project/word-reactor/)

**Word Reactor** is a Markov chain-based procedural name generator inside a physics simulation, written in Haxe. Run it [in the browser](http://www.samcodes.co.uk/project/word-reactor/).

Demonstrates the [Markov Namegen](https://github.com/Tw1ddle/MarkovNameGenerator) library.

## Usage ##

Run the live [demo](http://www.samcodes.co.uk/project/word-reactor/) and generate words. Tap topic balls to produce new words, drag and drop to generate hybrids and more:

[TODO screenshot]

Drag balls around to mix things up:

[TODO screenshot]

## Install ##

Get Markov Namegen on [GitHub](https://github.com/Tw1ddle/MarkovNameGenerator) or through [haxelib](http://lib.haxe.org/p/markov-namegen/), and read the [documentation here](http://tw1ddle.github.io/MarkovNameGenerator/).

Include it in your ```.hxml```
```
-lib markov-namegen
```

Or add it to your ```Project.xml```:
```
<haxelib name="markov-namegen" />
```

## How It Works ##

The [markov-namegen haxelib](http://lib.haxe.org/p/markov-namegen) uses [Markov chains](https://en.wikipedia.org/wiki/Markov_chain) to generate random words. Given a set of words as [training data](https://en.wikipedia.org/wiki/Machine_learning), the library calculates the conditional probability of a letter coming up after a sequence of letters chosen so far. It looks back up to "n" characters, where "n" is the order of the model.

The physics simulation is made using [Nape](https://github.com/deltaluca/nape), a 2D rigid body physics engine for Haxe. When balls containing topic words collide, new balls are created that contain words generated using the training data for those topics.

## Notes ##
* Inspired by the [ball pool](http://mrdoob.com/projects/chromeexperiments/ball-pool/) experiment by [Ricardo Cabello](https://twitter.com/mrdoob) and the sample projects from [Nape](https://github.com/deltaluca/nape) by [Luca Deltodesco](https://github.com/deltaluca).
* Many of the concepts used for the generator were suggested in [this article](http://www.roguebasin.com/index.php?title=Names_from_a_high_order_Markov_Process_and_a_simplified_Katz_back-off_scheme) by [Jeffrey Lund](https://github.com/jlund3).
* If you have any questions or suggestions then [get in touch](http://samcodes.co.uk/contact) or open an issue.

## License ##
The demo code is licensed under CC BY-NC. The [haxelib library](http://lib.haxe.org/p/markov-namegen/) itself is MIT licensed. Training data was compiled from sites like Wikipedia and census data sources.