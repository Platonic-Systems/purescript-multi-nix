import { zalgo } from "zalgo-js"

function zalgoize(str) {
	return zalgo(str, { seed: "PureScript ∪ Nix" })
}

export { zalgoize }
