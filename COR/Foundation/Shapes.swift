extension XY {

	/// ```
	/// .*.
	/// *o*
	/// .*.
	/// ```
	var n4: [4 of XY] {
		[XY(x + 1, y), XY(x, y + 1), XY(x - 1, y), XY(x, y - 1)]
	}

	/// ```
	/// *.*
	/// .o.
	/// *.*
	/// ```
	var x4: [4 of XY] {
		[
			XY(x + 1, y + 1), XY(x - 1, y + 1), XY(x - 1, y - 1), XY(x + 1, y - 1),
		]
	}

	/// ```
	/// .*.
	/// ***
	/// .*.
	/// ```
	var c5: [5 of XY] {
		[self, XY(x + 1, y), XY(x, y + 1), XY(x - 1, y), XY(x, y - 1)]
	}

	/// ```
	/// ***
	/// *o*
	/// ***
	/// ```
	var n8: [8 of XY] {
		[
			XY(x + 1, y), XY(x + 1, y + 1), XY(x, y + 1), XY(x - 1, y + 1),
			XY(x - 1, y), XY(x - 1, y - 1), XY(x, y - 1), XY(x + 1, y - 1),
		]
	}

	/// ```
	/// .***.
	/// *...*
	/// *.o.*
	/// *...*
	/// .***.
	/// ```
	var r12: [12 of XY] {
		[
			XY(x + 2, y), XY(x + 2, y + 1), XY(x + 2, y - 1),
			XY(x, y + 2), XY(x + 1, y + 2), XY(x - 1, y + 2),
			XY(x - 2, y), XY(x - 2, y + 1), XY(x - 2, y - 1),
			XY(x, y - 2), XY(x + 1, y - 2), XY(x - 1, y - 2),
		]
	}

	/// ```
	/// .***.
	/// *****
	/// **o**
	/// *****
	/// .***.
	/// ```
	var n20: [20 of XY] {
		[
			XY(x + 1, y), XY(x + 1, y + 1), XY(x, y + 1), XY(x - 1, y + 1),
			XY(x - 1, y), XY(x - 1, y - 1), XY(x, y - 1), XY(x + 1, y - 1),

			XY(x + 2, y), XY(x + 2, y + 1), XY(x + 2, y - 1),
			XY(x, y + 2), XY(x + 1, y + 2), XY(x - 1, y + 2),
			XY(x - 2, y), XY(x - 2, y + 1), XY(x - 2, y - 1),
			XY(x, y - 2), XY(x + 1, y - 2), XY(x - 1, y - 2),
		]
	}

	/// ```
	/// ..***..
	/// .*****.
	/// *******
	/// ***o***
	/// *******
	/// .*****.
	/// ..***..
	/// ```
	var n36: [36 of XY] {
		[
			XY(x + 1, y), XY(x + 1, y + 1), XY(x, y + 1), XY(x - 1, y + 1),
			XY(x - 1, y), XY(x - 1, y - 1), XY(x, y - 1), XY(x + 1, y - 1),

			XY(x + 2, y), XY(x + 2, y + 1), XY(x + 2, y - 1),
			XY(x, y + 2), XY(x + 1, y + 2), XY(x - 1, y + 2),
			XY(x - 2, y), XY(x - 2, y + 1), XY(x - 2, y - 1),
			XY(x, y - 2), XY(x + 1, y - 2), XY(x - 1, y - 2),

			XY(x + 2, y + 2), XY(x - 2, y + 2), XY(x + 2, y - 2), XY(x - 2, y - 2),

			XY(x + 3, y), XY(x + 3, y + 1), XY(x + 3, y - 1),
			XY(x, y + 3), XY(x + 1, y + 3), XY(x - 1, y + 3),
			XY(x - 3, y), XY(x - 3, y + 1), XY(x - 3, y - 1),
			XY(x, y - 3), XY(x + 1, y - 3), XY(x - 1, y - 3),
		]
	}

	/// ```
	/// ***
	/// ***
	/// ***
	/// ```
	var s9: [9 of XY] {
		[
			self,

			XY(x + 1, y), XY(x + 1, y + 1), XY(x, y + 1), XY(x - 1, y + 1),
			XY(x - 1, y), XY(x - 1, y - 1), XY(x, y - 1), XY(x + 1, y - 1),
		]
	}

	var s49: [49 of XY] {
		[
			self,

			XY(x + 1, y), XY(x + 1, y + 1), XY(x, y + 1), XY(x - 1, y + 1),
			XY(x - 1, y), XY(x - 1, y - 1), XY(x, y - 1), XY(x + 1, y - 1),

			XY(x + 2, y), XY(x + 2, y + 1), XY(x + 2, y - 1),
			XY(x, y + 2), XY(x + 1, y + 2), XY(x - 1, y + 2),
			XY(x - 2, y), XY(x - 2, y + 1), XY(x - 2, y - 1),
			XY(x, y - 2), XY(x + 1, y - 2), XY(x - 1, y - 2),

			XY(x + 2, y + 2), XY(x - 2, y + 2), XY(x + 2, y - 2), XY(x - 2, y - 2),

			XY(x + 3, y), XY(x + 3, y + 1), XY(x + 3, y - 1),
			XY(x, y + 3), XY(x + 1, y + 3), XY(x - 1, y + 3),
			XY(x - 3, y), XY(x - 3, y + 1), XY(x - 3, y - 1),
			XY(x, y - 3), XY(x + 1, y - 3), XY(x - 1, y - 3),

			XY(x + 3, y + 2), XY(x + 2, y + 3), XY(x - 2, y + 3), XY(x - 3, y + 2),
			XY(x - 3, y - 2), XY(x - 2, y - 3), XY(x + 2, y - 3), XY(x + 3, y - 2),
			XY(x + 3, y + 3), XY(x - 3, y + 3), XY(x - 3, y - 3), XY(x + 3, y - 3),
		]
	}
}
