package;

import haxe.ds.StringMap;
import js.Browser;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.DivElement;
import markov.namegen.Generator;
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
//@:build(CodeCompletion.buildUrl("http://www.samcodes.co.uk/project/word-reactor/"))
class ID {}

// Automatically reads training data from files into corresponding static arrays of strings in this class
@:build(TrainingDataBuilder.build("embed"))
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
	public var topic(default, null):String; // The training data category of the data (variable name in the TrainingDatas, not the data itself)
	
	public inline function new(container:DivElement, topic:String, type:BallType) {
		Sure.sure(container != null);
		Sure.sure(topic != null);

		var words:Array<String> = Reflect.field(TrainingDatas, topic);
		Sure.sure(words != null);
		
		this.container = container;
		
		if (type == BallType.TOPIC) {
			this.text = topic;
		}
		else if(type == BallType.WORD) {
			this.text = words[Std.int(Math.random() * words.length - 1)]; // Start with a random word from the training data
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

class Main {
	private static inline var GITHUB_URL:String = "https://github.com/Tw1ddle/word-reactor"; // The hosted repository URL
	private static inline var WEBSITE_URL:String = "http://www.samcodes.co.uk/project/word-reactor/"; // Hosted demo URL
	private static inline var TWITTER_URL:String = "https://twitter.com/Sam_Twidale"; // Project Twitter URL
	public static inline var BALL_CONTAINER_CLASSNAME:String = "ballContainer";
	public static inline var CONTENT_WRAPPER_CLASSNAME:String = "contentWrapper";
	public static inline var INNER_CONTENT_CLASSNAME:String = "innerContent";
	private static inline var FRAME_TIMEOUT_TIME_SECONDS:Int = 3;
	private static inline var GRAVITY_STRENGTH:Int = 600; // 600 pixels/units per second
	
	// Groups of related word generation topics
	private static var topicGroups:Array<Array<String>> = [
		["Animals", "Fish", "Pokemon"],
		["American Forenames", "Italian Forenames", "Japanese Forenames", "Swedish Forenames", "Tolkienesque Forenames"],
		["English Towns", "German Towns", "Japanese Cities", "Swiss Cities"]
	];
	private static var backgroundTappingTopic = "Pokemon"; // The topic used to generate balls when tapping the background
	
	private var div:DivElement = cast Browser.document.getElementById(ID.simulation); // The div that contains the whole simulation
	private var lastAnimationTime:Float = 0.0; // Last time from requestAnimationFrame
	
	private var generatorMap:StringMap<Generator>; // Maps training data types to word generators
	
	private var napeGravity:Vec2; // Gravity vector
	private var napeSpace:Space; // Simulation space
	private var napeHand:PivotJoint; // Used as a hand control for manipulating dynamic bodies with mouse/touch
	private var worldBorder:Body; // Nape screen borders
	private var wordBallCollisionType:CbType; // Callback type for when two balls that contain words collide
	private var topicBallCollisionType:CbType; // Callback type for when two balls that contain topics collide
	private var decorativeBalls:BodyList; // Balls that are purely decorative
	private var topicBalls:BodyList; // Balls that contain topics
	private var wordBalls:BodyList; // Balls that contain generated words
	private var instructionsBall:Body; // The instructions ball
	private var twitterBall:Body; // Ball with Twitter link
	private var githubBall:Body; // Ball with GitHub link
	private var pointerPosition:Vec2; // Last pointer position
	private var isPointerDown:Bool; // Is the pointer down or not
	
	private static function main():Void {
		var main = new Main();
	}

	private inline function new() {
		Browser.window.onload = onWindowLoaded;
	}
	
	private inline function onWindowLoaded():Void {
		resetSimulation();
		
		// Create pointer event methods
		var onPointerDown = function(x:Int, y:Int):Void {
			isPointerDown = true;
			napeHand.anchor1.setxy(x, y);
			pointerPosition.setxy(x, y);
			var bodies = new BodyList();
			bodies = napeSpace.bodiesUnderPoint(pointerPosition, null, bodies);
			for (body in bodies) {
				if (body.isDynamic()) {
					
					// Make the last selected ball the current topic ball if the user presses an empty space
					try {
						var userData = cast(body.userData.sprite, UserData);
						if (userData.type == BallType.TOPIC) {
							backgroundTappingTopic = userData.topic;
						}
					} catch (e:Dynamic) {
					}
					
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
		var onPointerUp = function(x:Int, y:Int):Void {
			isPointerDown = false;
			napeHand.anchor1.setxy(x, y);
			pointerPosition.setxy(x, y);
			napeHand.active = false;
		};
		
		// Setup event listeners
		Browser.document.addEventListener("mousedown", function(e:Dynamic):Void {
			onPointerDown(e.clientX, e.clientY);
			
			#if debug
			if (e.which == 3) { // Debug right click to reset
				resetSimulation();
			}
			#end
		}, false);
		Browser.document.addEventListener("mousemove", function(e:Dynamic):Void {
			onPointerMove(e.clientX, e.clientY);
		}, false);
		Browser.document.addEventListener("mouseup", function(e:Dynamic):Void {
			onPointerUp(e.clientX, e.clientY);
		}, false);
		Browser.document.addEventListener("touchstart", function(e:Dynamic):Void {
			onPointerDown(e.touches[0].clientX, e.touches[0].clientY);
		}, false);
		Browser.document.addEventListener("touchmove", function(e:Dynamic):Void {
			onPointerMove(e.touches[0].clientX, e.touches[0].clientY);
		}, false);
		Browser.document.addEventListener("touchend", function(e:Dynamic):Void {
			onPointerUp(e.touches[0].clientX, e.touches[0].clientY);
		}, false);
		Browser.window.addEventListener("resize", function():Void {
			// TODO implement resize
		}, false);
		Browser.window.addEventListener("deviceorientation", function(e:Dynamic):Void {
			if(e.beta != null) {
				napeGravity.x = Math.sin(e.gamma * Math.PI / 180);
				napeGravity.y = Math.sin((Math.PI / 4) + e.beta * Math.PI / 180);
			}
		}, false);
		
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
			// TODO add stream of words (and decorations) to the location until release
			var size = Std.int(25 + Math.random() * 50);
			
			var decorativeBall:Bool = Math.random() < 0.15;
			if (decorativeBall) {
				decorativeBalls.add(createDecorativeBall(size, pointerPosition.x, pointerPosition.y));
			} else {
				wordBalls.add(createWordBall(size, pointerPosition.x, pointerPosition.y, backgroundTappingTopic));
			}
		}
		
		for (ball in wordBalls) {
			updateBallStyle(ball.userData.sprite.container.style, ball.position.x, ball.position.y, ball.rotation);
		}
		for (ball in topicBalls) {
			updateBallStyle(ball.userData.sprite.container.style, ball.position.x, ball.position.y, ball.rotation);
		}
		for (ball in [instructionsBall, githubBall, twitterBall]) {
			if(ball != null) {
				updateBallStyle(ball.userData.sprite.style, ball.position.x, ball.position.y, ball.rotation);
			}
		}
		for(ball in decorativeBalls) {
			updateBallStyle(ball.userData.sprite.style, ball.position.x, ball.position.y, ball.rotation);
		}
		
		Browser.window.requestAnimationFrame(animate);
	}
	
	/**
	 * Resets the simulation to a sensible starting state
	 */
	private inline function resetSimulation():Void {
		div.innerHTML = ""; // Remove all the old graphical elements
		lastAnimationTime = 0.0;
		
		generatorMap = new StringMap<Generator>();
		
		napeGravity = Vec2.weak(0, GRAVITY_STRENGTH);
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
		
		decorativeBalls = new BodyList();
		
		topicBalls = new BodyList();
		var topics = topicGroups[Std.int(Math.random() * topicGroups.length -  1)];
		for (topic in topics) {
			topicBalls.add(createTopicBall(150, 200, 300, topic)); // TODO
		}
		
		wordBalls = new BodyList();
		for (i in 0...10) {
			// TODO move out/create columns for each topic?
			//wordBalls.add(createWordBall(80, 80, 100, 100)); // TODO
		}
		
		instructionsBall = createInstructions(320, 200, 200); // TODO
		githubBall = createClickableBall(128, 400, 400, GITHUB_URL, '<img src="assets/images/githublogo.png" />');
		twitterBall = createClickableBall(128, 400, 400, TWITTER_URL, '<img src="assets/images/twitterlogo.png" />');
		
		isPointerDown = false;
		pointerPosition = new Vec2(0, 0);
	}
	
	/**
	 * Helper function that updates the visual representation of a Nape body
	 */
	private inline function updateBallStyle(style:Dynamic, x:Float, y:Float, rotation:Float):Void {
		style.left = Std.string(x - Std.int(Std.parseFloat(StringTools.replace(style.width, "px", "")) / 2)) + "px";
		style.top = Std.string(y - Std.int(Std.parseFloat(StringTools.replace(style.height, "px", "")) / 2)) + "px";
		var transform = 'rotate(' + rotation * 57.2957795 + 'deg) translateZ(0)'; // TODO limit +- 45 and loop over to avoid the balls fully flipping and being hard to read?
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
	
	private inline function createWrappedContent():DivElement {
		var outer = Browser.document.createDivElement();
		outer.className = CONTENT_WRAPPER_CLASSNAME;
		
		var inner = Browser.document.createSpanElement();
		inner.className = INNER_CONTENT_CLASSNAME;
		inner.innerHTML = "";
		
		outer.appendChild(inner);
		
		return outer;
	}
	
	/**
	 * Creates a ball that contains a generated word
	 */
	private inline function createTopicBall(size:Int, startX:Int, startY:Int, topic:String):Body {
		var content = createWrappedContent();
		
		var circleContainer = createVisualBall(size, startX, startY, content);
		div.appendChild(circleContainer);
		
		var ball = createNapeBall(size, startX, startY);
		ball.userData.sprite = new UserData(circleContainer, topic, BallType.TOPIC);
		ball.cbTypes.add(topicBallCollisionType);
		return ball;
	}
	
	/**
	 * Creates a ball that contains a generated word
	 */
	private inline function createWordBall(size:Int, startX:Float, startY:Float, topic:String):Body {
		var content = createWrappedContent();
		
		var circleContainer = createVisualBall(size, startX, startY, content);
		div.appendChild(circleContainer);
		
		var ball = createNapeBall(size, startX, startY);
		ball.userData.sprite = new UserData(circleContainer, topic, BallType.WORD);
		ball.cbTypes.add(wordBallCollisionType);
		return ball;
	}
	
	/**
	 * Creates an entirely decorative ball
	 */
	private inline function createDecorativeBall(size:Int, startX:Float, startY:Float):Body {
		var circleContainer = Browser.document.createDivElement();
		circleContainer.className = BALL_CONTAINER_CLASSNAME;
		circleContainer.style.width = Std.string(size) + "px";
		circleContainer.style.height = Std.string(size) + "px";
		circleContainer.style.left = Std.string(startX);
		circleContainer.style.top = Std.string(startY);
		
		div.appendChild(circleContainer);
		
		var circle = Browser.document.createCanvasElement();
		circle.width = size;
		circle.height = size;
		
		var ctx = circle.getContext2d();
		var num_circles = 1 + Std.int(Math.random() * 10);
		var size = size;
		var i = size;
		while (i > 0) {
			var val = Std.string(Std.int(Math.random() * 255)); // TODO follow a gradient/theme?
			ctx.fillStyle = "rgb(" + val + "," + val + "," + val + ")";
			ctx.beginPath();
			ctx.arc(size / 2, size / 2, i / 2, 0, Math.PI * 2);
			ctx.closePath();
			ctx.fill();
			i -= Std.int(size / num_circles);
		}
		
		circleContainer.appendChild(circle);
		
		var ball = createNapeBall(size, startX, startY);
		ball.userData.sprite = circleContainer;
		return ball;
	}
	
	/**
	 * Creates a ball containing usage instructions and a click-to-reset function
	 */
	private inline function createInstructions(size:Int, startX:Int, startY:Int):Body {
		var content = createWrappedContent();

		var span = cast content.childNodes[0];
		span.innerHTML = '<h1>Reactor</h1><br/><br/><span style="font-size:15px;"><strong>Instructions:</strong><br/><br/>1. Drag and collide balls.<br/>2. Tap the background.<br/>3. Double tap here.<br/>4. Have fun!</span>';
		var circleContainer = createVisualBall(size, startX, startY, content);
		div.appendChild(circleContainer);
		var ball = createNapeBall(size, startX, startY);
		ball.userData.sprite = circleContainer;
		return ball;
	}
	
	/**
	 * Creates a ball containing a clickable image that opens a URL
	 */
	private inline function createClickableBall(size:Int, startX:Int, startY:Int, url:String, innerHTML:String):Body {
		var content = createWrappedContent();
		var circleContainer = createVisualBall(
		size,
		startX,
		startY,
		content,
		false,
		null
		);
		div.appendChild(circleContainer);
		
		circleContainer.addEventListener("click", function(e:Dynamic):Void {
			Browser.window.open(url);
		}, false);
		
		circleContainer.innerHTML = innerHTML;
		
		var ball = createNapeBall(size, startX, startY);
		ball.userData.sprite = circleContainer;
		return ball;
	}
	
	/**
	 * Helper function for creating a canvas visual of a Nape ball
	 */
	private inline function createVisualBall(size:Int, startX:Float, startY:Float, innerBody:DivElement, useCanvas:Bool = true, ?fillTechnique:CanvasRenderingContext2D->Int->Int->Void):DivElement {
		var container = Browser.document.createDivElement();
		container.className = BALL_CONTAINER_CLASSNAME;
		container.style.width = Std.string(size) + "px";
		container.style.height = Std.string(size) + "px";
		container.style.left = Std.string(startX);
		container.style.top = Std.string(startY);
		
		if(useCanvas) {
			var circle:CanvasElement = Browser.document.createCanvasElement();
			circle.width = size;
			circle.height = size;
			var ctx:CanvasRenderingContext2D = circle.getContext2d();
			if (fillTechnique != null) {
				fillTechnique(ctx, size, size);
			} else {
				ctx.fillStyle = "solid";
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
	private inline function createNapeBall(size:Int, startX:Float, startY:Float):Body {
		var ball = new Body(BodyType.DYNAMIC);
		ball.position.setxy(startX, startY);
		ball.shapes.add(new Circle(Std.int(size / 2)));
		ball.space = napeSpace;
		return ball;
	}
	
	/**
	 * Collision callback that runs when two word-containing balls collide
	 */
	private inline function wordOnWordCollision(cb:InteractionCallback):Void {
		//var ball = createDecorativeBall(50, Std.int(cb.int1.castBody.position.x), Std.int(cb.int1.castBody.position.y)); // TODO dynamic resize balls?
		//decorativeBalls.add(ball); // TODO
	}
	
	/**
	 * Collision callback that runs when two topic-containing balls collide
	 */
	private inline function topicOnTopicCollision(cb:InteractionCallback):Void {
		var word1:UserData = cast cb.int1.userData.sprite;
		var word2:UserData = cast cb.int2.userData.sprite;
		
		// TODO create a hybrid word or a random one from one or the other?
		var ball = createWordBall(80, Std.int(cb.int1.castBody.position.x), Std.int(cb.int1.castBody.position.y), word1.topic); // TODO size
		wordBalls.add(ball);
	}
	
	/**
	 * Generates a word for the given topic using a procedural word generator
	 */
	private inline function generate(topic:String):String {
		var generator = getGenerator(topic);
		var name = "";
		while (name == null || name == "") {
			name = generator.generate();
		}
		return StringTools.replace(name, "#", "");
	}
	
	/**
	 * Helper function that returns a word generator for the given topic
	 */
	private inline function getGenerator(topic:String):Generator {
		var generator = generatorMap.get(topic);
		if (generator == null) {
			generator = new Generator(Reflect.field(TrainingDatas, topic), 3, 0);
			generatorMap.set(topic, generator);
		}
		return generator;
	}
}