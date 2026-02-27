																							

func tokenise(text: String) -> Array:
	
	var twoCharOps : Array = ["==", "!=", "<=", ">="]
	var oneCharOps : Array = ["+", "-", "*", "/", "=", "%", "(", ")", "{", "}", ";"]
	
	var tokens : Array = []
	var i : int = 0
	
	while i < text.length():
		var c = text[i]

		# Skip whitespace
		if c.remove_chars(" ") == "":
			i += 1
			continue

		# ------------------------
		# IDENTIFIERS / KEYWORDS
		# ------------------------
		if c.is_valid_identifier():
			var start = i
			while i < text.length() and (text[i].is_valid_identifier() or text[i].is_valid_float()):
				i += 1

			var word = text.substr(start, i - start)
			tokens.append(word)
			continue

		# ------------------------
		# NUMBERS (ints + floats)
		# ------------------------
		if c.is_valid_float():
			var start = i
			var has_dot = false

			while i < text.length():
				if text[i].is_valid_float():
					i += 1
				elif text[i] == "." and not has_dot:
					has_dot = true
					i += 1
				else:
					break

			var number = text.substr(start, i - start)
			tokens.append(number)
			continue


# ------------------------
		# DOUBLE OPERATORS
		# ------------------------
		if i < text.length() - 1:
			var pair = text[i] + text[i + 1]
			if pair in twoCharOps:
				tokens.append(pair)
				i += 2
				continue

		# ------------------------
		# SINGLE OPERATORS
		# ------------------------
		if c in oneCharOps:
			tokens.append(c)
			i += 1
			continue

		# ------------------------
		# UNKNOWN CHARACTER
		# ------------------------
		push_error("Unknown character: " + c)
		i += 1

	return tokens
