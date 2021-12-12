package;

import haxe.ds.StringMap;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.DivElement;
import markov.namegen.Generator;
import markov.util.TrainingDataBuilder;
import markov.util.PrefixTrie;
import nape.callbacks.CbEvent;
import nape.callbacks.CbType;
import nape.callbacks.InteractionCallback;
import nape.callbacks.InteractionListener;
import nape.callbacks.InteractionType;
import nape.constraint.PivotJoint;
import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyList;
import nape.phys.BodyType;
import nape.shape.Circle;
import nape.shape.Polygon;
import nape.space.Space;

// Automatic HTML code completion, you need to point these to your debug/release HTML
#if debug
@:build(CodeCompletion.buildLocalFile("bin/debug/index.html"))
#else
@:build(CodeCompletion.buildLocalFile("bin/release/index.html"))
#end
//@:build(CodeCompletion.buildUrl("https://www.samcodes.co.uk/project/word-reactor/"))
class ID {}

// Automatically reads training data from files into corresponding static arrays of strings in this class
@:build(markov.util.TrainingDataBuilder.build("embed"))
@:keep
class TrainingDatas {}

// Types of balls in the simulation
@:enum abstract BallType(Int) {
	var TOPIC = 0;
	var WORD = 1;
}

// User data that is attached to Nape balls, for use in handling word generation when collisions happen
class UserData {
	public var type:BallType;
	public var container(default, null):DivElement; // The HTML element that holds the ball text
	public var text(default, set):String; // The actual text content of the ball
	public var topic(default, null):Topic; // The training data category of the data (the name corresponds to the variable in the TrainingDatas, not the data itself)
	
	public inline function new(container:DivElement, topic:Topic, ?text:String, type:BallType) {
		Sure.sure(container != null);
		Sure.sure(topic != null);
		
		this.container = container;
		
		if (type == BallType.TOPIC) {
			this.text = StringTools.replace(topic.name, "_", " ");
		} else {
			Sure.sure(text != null);
			this.text = text;
		}
		
		this.topic = topic;
		this.type = type;
	}
	
	private function set_text(text:String):String {
		Sure.sure(text != null && text.length > 0);
		
		this.text = text;
		container.getElementsByClassName(Main.INNER_CONTENT_CLASSNAME)[0].innerHTML = text;
		return this.text;
	}
}

// A name generator paired with a trie (used to efficiently avoid creating duplicate words)
class GeneratorTriePair {
	public var generator(default, null):Generator;
	public var trie(default, null):PrefixTrie;
	
	public inline function new(generator:Generator, trie:PrefixTrie) {
		this.generator = generator;
		this.trie = trie;
	}
}

class Topic {
	public var name(default, null):String;
	public var color(default, null):String;
	public inline function new(name:String, color:String) {
		this.name = StringTools.replace(name.toLowerCase(), " ", "_");
		this.color = color;
	}
}

class Main {
	private static inline var GITHUB_URL:String = "https://github.com/Tw1ddle/word-reactor"; // The hosted repository URL
	private static inline var WEBSITE_URL:String = "https://www.samcodes.co.uk/project/word-reactor/"; // Hosted demo URL
	private static inline var TWITTER_URL:String = "https://twitter.com/Sam_Twidale/status/756230840821092352"; // Project Twitter URL
	public static inline var BALL_CONTAINER_CLASSNAME:String = "ballContainer";
	public static inline var CONTENT_WRAPPER_CLASSNAME:String = "contentWrapper";
	public static inline var INNER_CONTENT_CLASSNAME:String = "innerContent";
	private static inline var FRAME_TIMEOUT_TIME_SECONDS:Int = 3;
	private static inline var GRAVITY_STRENGTH:Int = 600; // 600 pixels/units per second
	
	// Groups of related word generation topics
	private static var topicGroups:Array<Array<Topic>> = [
		[new Topic("American Desserts", "#35203b"), new Topic("British Desserts", "#cf4a30")],
		[new Topic("Musical Styles", "#28687c"), new Topic("Musical Instruments", "#0f384a")],
		[new Topic("Clothing", "#16193b"), new Topic("Colours", "#35478c")],
		[new Topic("Fruit", "#93004f"), new Topic("Meats", "#009f43"), new Topic("Breakfast Cereals", "#000093")],
		[new Topic("Original Pokemon", "#222222"), new Topic("Animals", "#444444"), new Topic("Modern Pokemon", "#666666")],
		[new Topic("American Forenames", "#ff8000"), new Topic("Japanese Forenames", "#cccc52"), new Topic("Tolkienesque Forenames", "#129b33")],
		[new Topic("English Towns", "#8cbeb2"), new Topic("German Towns", "#f3b562"), new Topic("Japanese Cities", "#aa6060")]
	];
	private static var backgroundTappingTopic = topicGroups[0][0]; // The topic used to generate balls when tapping the background
	private var currentTopicGroup:Array<Topic>;
	private var currentTopicGroupCounter:Int = 0; // Counter to facilitate looping through topic groups
	private var currentTopicCounter:Int; // Counter to facilitate looping through topics
	
	private var div:DivElement = cast Browser.document.getElementById(ID.simulation); // The div that contains the whole simulation
	private var lastAnimationTime:Float = 0.0; // Last time from requestAnimationFrame
	
	private var generatorMap:StringMap<GeneratorTriePair>; // Maps training data types to word generators
	
	private var napeGravity:Vec2; // Gravity vector
	private var napeSpace:Space; // Simulation space
	private var napeHand:PivotJoint; // Used as a hand control for manipulating dynamic bodies with mouse/touch
	private var worldBorder:Body; // Nape screen borders
	private var wordBallCollisionType:CbType; // Callback type for when two balls that contain words collide
	private var topicBallCollisionType:CbType; // Callback type for when two balls that contain topics collide
	private var topicBalls:BodyList; // Balls that contain topics
	private var wordBalls:BodyList; // Balls that contain generated words
	private var instructionsBall:Body; // The instructions ball
	private var twitterBall:Body; // Ball with Twitter link
	private var githubBall:Body; // Ball with GitHub link
	private var resetBall:Body; // Ball with a click to reset the simulation option
	private var pointerPosition:Vec2; // Last pointer position
	private var isPointerDown:Bool; // Is the pointer down or not
	
	private var wordFontSizePixels:Int; // The font size of the word ball text
	private var topicFontSizePixels:Int; // The font size of the word ball text
	private var wordBallPixelPadding:Int; // The extra space in addition to the ball text width
	private var topicBallPixelPadding:Int; // The extra space in addition to the ball text width
	
	private static function main():Void {
		var main = new Main();
	}

	private inline function new() {
		Browser.window.onload = onWindowLoaded;
	}
	
	private inline function onWindowLoaded():Void {
		generatorMap = new StringMap<GeneratorTriePair>();
		
		napeGravity = new Vec2(0, GRAVITY_STRENGTH); // Default to portrait gravity
		
		resetSimulation();
		
		// Create pointer event methods
		var onPointerDown = function(x:Int, y:Int):Void {
			isPointerDown = true;
			napeHand.anchor1.setxy(x, y);
			pointerPosition.setxy(x, y);
			var bodies = new BodyList();
			bodies = napeSpace.bodiesUnderPoint(pointerPosition, null, bodies);
			
			if (bodies == null || bodies.length == 0) {
				backgroundTappingTopic = getNextTopic(); // Change the background spawning topic every time the mouse is pressed down on an empty area
			}
			
			for (body in bodies) {
				if (body.isDynamic()) {
					/*
					// Makes the last selected topic ball the current topic (for spawning when the user presses an empty space)
					try {
						var userData = cast(body.userData.sprite, UserData);
						if (userData.type == BallType.TOPIC) {
							backgroundTappingTopic = userData.topic;
						}
					} catch (e:Dynamic) {
					}
					*/
					
					napeHand.body2 = body;
					napeHand.anchor2 = body.worldPointToLocal(pointerPosition, true);
					napeHand.active = true;
					break;
				}
			}
		};
		var onPointerMove = function(x:Int, y:Int):Void {
			napeHand.anchor1.setxy(x, y);
			pointerPosition.setxy(x, y);
		};
		var onPointerUp = function():Void {
			isPointerDown = false;
			napeHand.active = false;
		};
		
		// Setup event listeners
		Browser.document.addEventListener("mousedown", function(e:Dynamic):Void {
			onPointerDown(e.clientX, e.clientY);
			e.preventDefault();
			
			#if debug
			if (e.which == 3) { // Debug right click to reset
				resetSimulation();
			}
			#end
		}, true);
		Browser.document.addEventListener("mousemove", function(e:Dynamic):Void {
			onPointerMove(e.clientX, e.clientY);
			e.preventDefault();
		}, true);
		Browser.document.addEventListener("mouseup", function(e:Dynamic):Void {
			onPointerUp();
			e.preventDefault();
		}, true);
		Browser.document.addEventListener("touchstart", function(e:Dynamic):Void {
			onPointerDown(e.touches[0].clientX, e.touches[0].clientY);
			e.preventDefault();
		}, true);
		Browser.document.addEventListener("touchmove", function(e:Dynamic):Void {
			onPointerMove(e.touches[0].clientX, e.touches[0].clientY);
			e.preventDefault();
		}, true);
		Browser.document.addEventListener("touchend", function(e:Dynamic):Void {
			onPointerUp();
			e.preventDefault();
		}, true);
		Browser.document.addEventListener("touchcancel", function(e:Dynamic):Void {
			onPointerUp();
			e.preventDefault();
		}, true);
		Browser.window.addEventListener("resize", function():Void {
			// NOTE can only really resize by squishing the balls together, so not doing it for now
		}, true);
		Browser.window.addEventListener("orientationchange", function():Void {
			switch(Browser.window.orientation) {
				case -90, 90:
					napeGravity = Vec2.weak(GRAVITY_STRENGTH, 0);
				default:
					napeGravity = Vec2.weak(0, GRAVITY_STRENGTH);
			}
		});
		
		Browser.window.requestAnimationFrame(animate); // Start the animation
	}
	
	private function animate(time:Float):Void {
		var dt:Float = (time - lastAnimationTime) * 0.001; // Seconds
		lastAnimationTime = time;
		
		if (dt > FRAME_TIMEOUT_TIME_SECONDS) {
			Browser.window.requestAnimationFrame(animate); // If the last frame rendered a long time ago, the user probably switched tabs for a bit - so pass small dt and render again (avoids physics weirdness)
			return;
		}
		
		napeSpace.step(dt, 10, 10); // Update simulation
		
		if (napeHand.active) {
			napeHand.body2.angularVel *= 0.95; // Diminish the currently held ball's angular velocity
		} else if (isPointerDown) {
			wordBalls.add(createWordBall(pointerPosition.x, pointerPosition.y, backgroundTappingTopic));
		}
		
		for (ball in wordBalls) {
			updateBallStyle(ball.userData.sprite.container.style, ball.position.x, ball.position.y, ball.rotation);
		}
		for (ball in topicBalls) {
			updateBallStyle(ball.userData.sprite.container.style, ball.position.x, ball.position.y, ball.rotation);
		}
		for (ball in [instructionsBall, githubBall, twitterBall, resetBall]) {
			if(ball != null) {
				updateBallStyle(ball.userData.sprite.style, ball.position.x, ball.position.y, ball.rotation);
			}
		}
		
		Browser.window.requestAnimationFrame(animate);
	}
	
	/**
	 * Resets the simulation to a sensible starting state
	 */
	private inline function resetSimulation():Void {
		while (div.firstChild != null) {
			div.removeChild(div.firstChild); // Remove all the old graphical elements
		}
		lastAnimationTime = 0.0;
		
		var screenWidth:Float = Browser.window.innerWidth;
		var screenHeight:Float = Browser.window.innerHeight;
		
		// NOTE somewhat hardcoded values...
		wordFontSizePixels = Std.int(Math.max(Math.min(screenWidth, screenHeight) * 0.01, 12));
		wordBallPixelPadding = wordFontSizePixels * 2;
		topicFontSizePixels = Std.int(Math.max(Math.min(screenWidth, screenHeight) * 0.015, 18));
		topicBallPixelPadding = topicFontSizePixels * 2;
		
		napeSpace = new Space(napeGravity); // The Nape simulation space
		napeHand = new PivotJoint(napeSpace.world, null, Vec2.weak(), Vec2.weak());
		napeHand.active = false;
		napeHand.stiff = false;
		napeHand.maxForce = 1500000;
		napeHand.space = napeSpace;
		worldBorder = createWorldBorder(0, 0, Browser.window.innerWidth, Browser.window.innerHeight, 100);
		worldBorder.space = napeSpace;
		
		// Setup ball-on-ball interactions
		wordBallCollisionType = new CbType();
		napeSpace.listeners.add(new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, wordBallCollisionType, wordBallCollisionType, wordOnWordCollision));
		
		topicBallCollisionType = new CbType();
		napeSpace.listeners.add(new InteractionListener(CbEvent.BEGIN, InteractionType.COLLISION, topicBallCollisionType, topicBallCollisionType, topicOnTopicCollision));
		
		topicBalls = new BodyList();
		
		currentTopicGroup = getNextTopicGroup();
		
		for (i in 0...currentTopicGroup.length) {
			topicBalls.add(createTopicBall(screenWidth * 0.5, screenHeight * 0.5, currentTopicGroup[i]));
		}
		
		wordBalls = new BodyList();
		
		instructionsBall = createInstructions(300, screenWidth * 0.5, screenHeight * 0.5); // NOTE fixed size
		githubBall = createClickableBall(96, screenWidth * 0.2, screenHeight * 0.1, function() { Browser.window.open(GITHUB_URL); }, '<img src="assets/images/githublogo.png" />');
		twitterBall = createClickableBall(96, screenWidth * 0.5, screenHeight * 0.1, function() { Browser.window.open(TWITTER_URL); }, '<img src="assets/images/twitterlogo.png" />');
		resetBall = createClickableBall(96, screenWidth * 0.8, screenHeight * 0.1, function() { resetSimulation(); }, '<img src="assets/images/reseticon.png" />');
		
		isPointerDown = false;
		pointerPosition = new Vec2(0, 0);
	}
	
	/**
	 * Helper function that updates the visual representation of a Nape body
	 */
	private inline function updateBallStyle(style:Dynamic, x:Float, y:Float, rotation:Float):Void {
		style.left = Std.string(x - Std.int(Std.parseFloat(StringTools.replace(style.width, "px", "")) / 2)) + "px";
		style.top = Std.string(y - Std.int(Std.parseFloat(StringTools.replace(style.height, "px", "")) / 2)) + "px";
		var degrees = rotation * 57.2957795;
		degrees = degrees < 0 ? Math.max(-33, degrees) : Math.min(33, degrees); 
		var transform = 'rotate(' + degrees + 'deg) translateZ(0)'; // NOTE could limit this to avoid the balls fully flipping and being hard to read. Or possibly instead, tween the text on inactive bodies back to a readable position?
		style.WebkitTransform = transform;
		style.MozTransform = transform;
		style.OTransform = transform;
		style.msTransform = transform;
		style.transform = transform;
	}
	
	/**
	 * Creates a hollow rectangle border to contain the simulation
	 */
	private inline function createWorldBorder(x:Int, y:Int, width:Int, height:Int, wallThickness:Int):Body {
		var bounds = new Body(BodyType.STATIC);
		bounds.shapes.add(new Polygon(Polygon.rect(x, y - wallThickness, width, wallThickness))); // Top
		bounds.shapes.add(new Polygon(Polygon.rect(x, y + height, width, wallThickness))); // Bottom
		bounds.shapes.add(new Polygon(Polygon.rect(x - wallThickness, y, wallThickness, height))); // Left
		bounds.shapes.add(new Polygon(Polygon.rect(x + width, y, wallThickness, height))); // Right
		return bounds;
	}
	
	private inline function createWrappedContent(?fontSize:Int):DivElement {
		var outer = Browser.document.createDivElement();
		outer.className = CONTENT_WRAPPER_CLASSNAME;
		
		var inner = Browser.document.createSpanElement();
		inner.className = INNER_CONTENT_CLASSNAME;
		inner.innerHTML = "";
		
		if(fontSize != null) {
			inner.style.fontSize = Std.string(fontSize) + "px";
		}
		
		outer.appendChild(inner);
		return outer;
	}
	
	/**
	 * Creates a ball that contains a generated word
	 */
	private inline function createTopicBall(startX:Float, startY:Float, topic:Topic):Body {
		var content = createWrappedContent(topicFontSizePixels);
		
		var radius = (topic.name.length * topicFontSizePixels) * 0.5 + topicBallPixelPadding;
		
		var circleContainer = createVisualBall(radius, startX, startY, content, topic);
		div.appendChild(circleContainer);
		
		var ball = createNapeBall(radius, startX, startY);
		ball.userData.sprite = new UserData(circleContainer, topic, BallType.TOPIC);
		ball.cbTypes.add(topicBallCollisionType);
		return ball;
	}
	
	/**
	 * Creates a ball that contains a generated word
	 */
	private inline function createWordBall(startX:Float, startY:Float, topic:Topic):Body {
		var content = createWrappedContent(wordFontSizePixels);
		
		var words:Array<String> = Reflect.field(TrainingDatas, topic.name);
		Sure.sure(words != null);
		var word = generate(topic.name);
		
		var radius = (word.length * wordFontSizePixels) * 0.5  + wordBallPixelPadding;
		
		var circleContainer = createVisualBall(radius, startX, startY, content, topic);
		div.appendChild(circleContainer);
		
		var userData = new UserData(circleContainer, topic, word, BallType.WORD);
		
		var ball = createNapeBall(radius, startX, startY);
		ball.userData.sprite = userData;
		ball.cbTypes.add(wordBallCollisionType);
		return ball;
	}
	
	/**
	 * Creates a ball containing usage instructions and a click-to-reset function
	 */
	private inline function createInstructions(size:Float, startX:Float, startY:Float):Body {
		var content = createWrappedContent();

		var span = cast content.childNodes[0];
		span.innerHTML = '<h1>Word Reactor</h1><br/><span style="font-size:15px;"><strong>Instructions:</strong><br/><br/>1. Drag and collide balls.<br/>2. Tap the background.<br/>3. Tap reset ball.<br/>4. Have fun!</span>';
		var circleContainer = createVisualBall(size, startX, startY, content, currentTopicGroup[0]);
		div.appendChild(circleContainer);
		var ball = createNapeBall(size, startX, startY);
		ball.userData.sprite = circleContainer;
		return ball;
	}
	
	/**
	 * Creates a ball containing a clickable image that opens a URL
	 */
	private inline function createClickableBall(size:Float, startX:Float, startY:Float, callback:Void->Void, innerHTML:String):Body {
		var content = createWrappedContent();
		var circleContainer = createVisualBall(size, startX, startY, content, topicGroups[0][0], false, null);
		div.appendChild(circleContainer);
		
		circleContainer.addEventListener("click", function(e:Dynamic):Void {
			callback();
		}, false);
		circleContainer.addEventListener("touchstart", function(e:Dynamic):Void {
			callback();
		}, false);
		
		circleContainer.innerHTML = innerHTML;
		
		var ball = createNapeBall(size, startX, startY);
		ball.userData.sprite = circleContainer;
		return ball;
	}
	
	/**
	 * Helper function for creating a canvas visual of a Nape ball
	 */
	private inline function createVisualBall(size:Float, startX:Float, startY:Float, innerBody:DivElement, topic:Topic, useCanvas:Bool = true, ?fillTechnique:CanvasRenderingContext2D->Int->Int->Void):DivElement {
		var container = Browser.document.createDivElement();
		container.className = BALL_CONTAINER_CLASSNAME;
		container.style.width = Std.string(size) + "px";
		container.style.height = Std.string(size) + "px";
		container.style.left = Std.string(startX) + "px";
		container.style.top = Std.string(startY) + "px";
		
		if(useCanvas) {
			var circle:CanvasElement = Browser.document.createCanvasElement();
			circle.width = Std.int(size);
			circle.height = Std.int(size);
			var ctx:CanvasRenderingContext2D = circle.getContext2d();
			if (fillTechnique != null) {
				fillTechnique(ctx, Std.int(size), Std.int(size));
			} else {
				ctx.fillStyle = topic.color;
				ctx.beginPath();
				ctx.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2);
				ctx.closePath();
				ctx.fill();
			}
			container.appendChild(circle);
		}
		
		container.appendChild(innerBody);
		return container;
	}
	
	/**
	 * Helper function for creating a Nape ball
	 */
	private inline function createNapeBall(size:Float, startX:Float, startY:Float):Body {
		var ball = new Body(BodyType.DYNAMIC);
		ball.position.setxy(startX, startY);
		ball.shapes.add(new Circle(Std.int(size / 2)));
		ball.space = napeSpace;
		ball.angularVel = Math.random() * 2 - 1;
		
		return ball;
	}
	
	/**
	 * Collision callback that runs when two word-containing balls collide
	 */
	private inline function wordOnWordCollision(cb:InteractionCallback):Void {
		// Unimplemented
	}
	
	/**
	 * Collision callback that runs when two topic-containing balls collide
	 */
	private inline function topicOnTopicCollision(cb:InteractionCallback):Void {
		var word1:UserData = cast cb.int1.userData.sprite;
		var word2:UserData = cast cb.int2.userData.sprite;
		var ball = createWordBall(Std.int(cb.int1.castBody.position.x), Std.int(cb.int1.castBody.position.y), word1.topic); // NOTE could create a hybrid word at this point, rather than just using the held topic
		wordBalls.add(ball);
	}
	
	/**
	 * Generates a word for the given topic using a procedural word generator
	 */
	private inline function generate(topic:String):String {
		var pair = getGenerator(topic);
		
		var makeWord = function() {
			var word = "";
			while (word == null || word.length == 0) {
				word = pair.generator.generate();
			}
			return StringTools.replace(word, "#", ""); // Strip hashes
		}
		var word = makeWord();
		while (pair.trie.find(word) || (word.length < 5 || word.length > 13)) { // No really short or super long words. NOTE could make this topic specific
			word = makeWord();
		}
		var firstLetter = word.charAt(0).toUpperCase();
		return firstLetter + word.substring(1, word.length);
	}
	
	/**
	 * Helper function that returns a word generator for the given topic
	 */
	private inline function getGenerator(topic:String):GeneratorTriePair {
		var pair = generatorMap.get(topic);
		if (pair == null) {
			var data = Reflect.field(TrainingDatas, topic);
			Sure.sure(data != null);
			
			var generator = new Generator(data, 3, 0, false);
			
			var trie = new PrefixTrie();
			for (word in data) {
				trie.insert(word);
			}
			
			pair = new GeneratorTriePair(generator, trie);
			generatorMap.set(topic, pair);
		}
		return pair;
	}
	
	private function getNextTopicGroup():Array<Topic> {
		currentTopicCounter = 0;
		var group = topicGroups[currentTopicGroupCounter % (topicGroups.length)];
		currentTopicGroupCounter++;
		return group;
	}
	
	private inline function getNextTopic():Topic {
		currentTopicCounter++;
		var topic = currentTopicGroup[currentTopicCounter % (currentTopicGroup.length)];
		return topic;
	}
}