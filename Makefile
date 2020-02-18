compile: testris.p8
	clear && clear
	pico8 -x $<

run: testris.p8
	clear && clear
	pico8 -run $<
