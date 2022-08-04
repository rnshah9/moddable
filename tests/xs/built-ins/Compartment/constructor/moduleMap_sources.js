/*---
description: 
flags: [module]
---*/

const foo = { source:`
	let foo = 0;
	export default function() {
		return foo++;
	}
`};

let getterCount = 0;
let setterCount = 0;
const moduleMap = {
	foo,
	get bar() {
		getterCount++;
		return this.foo;
	},
	set bar(it) {
		setterCount++;
		this.foo = it;
	},
};

const c1 = new Compartment({}, moduleMap, {});
const fooNS1 = await c1.import("foo");
const barNS1 = await c1.import("bar");

const c2 = new Compartment({}, moduleMap, {});
const fooNS2 = await c2.import("foo");
const barNS2 = await c2.import("bar");

assert.sameValue(getterCount, 2, "getterCount");
assert.sameValue(setterCount, 0, "setterCount");
assert.sameValue(fooNS1.default(), 0, "fooNS1.default()");
assert.sameValue(barNS1.default(), 0, "barNS1.default()");
assert.sameValue(fooNS2.default(), 0, "fooNS2.default()");
assert.sameValue(barNS2.default(), 0, "barNS2.default()");