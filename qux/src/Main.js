import zalgo from "zalgo-js"

function zalgoize(str) {
	return zalgo.default(str, { seed: "PureScript ∪ Nix" })
}

export { zalgoize }
