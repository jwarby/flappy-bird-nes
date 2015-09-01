default:
	nesasm flappy-bird.asm

run: default
	wine ~/Programs/fceuxdsp/fceuxdsp.exe flappy-bird.nes
