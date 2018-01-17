/**
 * Escapes a string from a char with a given escaper char
 *
 * @param input			The string to escape
 * @param escape		Char to escape
 * @param escaper		Char to escape with
 * @param output		Output string to store escaped string
 * @param maxlen		Size of the output string
 *
 * @return 				Number of escaped chars 
 */
stock EscapeString(String:input[], escape, escaper, String:output[], maxlen)
{
	// Number of chars we escaped
	new escaped = 0;

	// Format output buffer to ""
	Format(output, maxlen, "");


	// For each char in the input string
	for (new offset = 0; offset < strlen(input); offset++)
	{
		// Get char at the current position
		new ch = input[offset];

		// Found the escape or escaper char
		if (ch == escape || ch == escaper)
		{
			// Escape the escape char with the escaper^^
			Format(output, maxlen, "%s%c%c", output, escaper, ch);

			// Increase numbers of chars we escaped
			escaped++;
		}
		else
		{
			// And add chat to output buffer
			Format(output, maxlen, "%s%c", output, ch);
		}
	}

	// Return escaped chars
	return escaped;
}

/**
 * Escapes string's ' or " chars with MySQL rules. Escape char is the \ char
 *
 * @param input			The string to escape
 * @param output		Output string to store escaped string
 * @param maxlen		Size of the output string
 * @param escape 		True to escape ' char, false to escape " char
 *
 * @return 				Number of escaped chars 
 */
stock EscapeStringMySQL(String:input[], String:output[], maxlen, bool:escape = true)
{
	// Number of chars we escaped
	new escaped = 0;


	// Escape the ' char
	if (escape)
	{
		escaped = EscapeString(input, '\'', '\\', output, maxlen);
	}

	// Escape the " char
	else
	{
		escaped = EscapeString(input, '"', '\\', output, maxlen);
	}


	// Return escaped chars
	return escaped;
}


/**
 * Escapes string's ' or " chars with SQLite rules. Escape char is the ' or " char
 *
 * @param input			The string to escape
 * @param output		Output string to store escaped string
 * @param maxlen		Size of the output string
 * @param escape 		True to escape ' char, false to escape " char
 *
 * @return 				Number of escaped chars 
 */
stock EscapeStringSQLite(String:input[], String:output[], maxlen, bool:escape = true)
{
	// Number of chars we escaped
	new escaped = 0;


	// Escape the ' char
	if (escape)
	{
		escaped = EscapeString(input, '\'', '\'', output, maxlen);
	}

	// Escape the " char
	else
	{
		escaped = EscapeString(input, '"', '"', output, maxlen);
	}


	// Return escaped chars
	return escaped;
}