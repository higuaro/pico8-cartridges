comp: testris.p8
	clear
	pico8 -x $<

run: testris.p8
	clear
	pico8 -run $<
