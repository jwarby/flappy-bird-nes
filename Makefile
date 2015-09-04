default:
	nesasm flappy-bird.asm
	mv flappy-bird.nes dist/

run: default
	wine ~/Programs/fceuxdsp/fceuxdsp.exe dist/flappy-bird.nes
