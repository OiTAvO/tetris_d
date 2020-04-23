module source.app;

import core.stdc.wchar_;
import core.sys.windows.windows;
import core.time;
import core.thread;
import std.random;
import std.stdio;

/// represents the Field Width
enum nFieldWidth = 12;
/// represents the Field Height
enum nFieldHeight = 18;
/// represents the Screen Width
enum nScreenWidth = 120;
/// represents the Screen Height
enum nScreenHeight = 30;

/// all tetris pieces
const tetromino = [
	"..X...X...X...X.",
	"..X..XX...X.....",
	".....XX..XX.....",
	"..X..XX..X......",
	".X...XX...X.....",
	".X...X...XX.....",
	"..X...X..XX....."
];

/// represents the field, pieces and boundary
char[nFieldWidth * nFieldHeight] pField = 0;  //init all pField with 0

/**
	Rotate index position of the piece.

	Params:
		px = x position of the piece.
		py = y position of the piece.
		r = rotation angle.

	Returns:
		Rotated index position of the piece.
*/
int rotate(int px, int py, int r)
{
    final switch (r % 4)
    {
        case 0: return (py * 4) + px;
        case 1: return 12 + py - (px * 4);
        case 2: return 15 - px - (py * 4);
        case 3: return 3 - py + (px * 4);
    }
}

/**
	Checks if the piece fit in position.

	Params:
		nTetromino = piece index in tetromino.
		nRotation = rotation angle.
		nPosX = x position in field.
		nPosY = y position in field.

	Returns:
		True if the piece fits in position.
*/
bool doesPieceFit(int nTetromino, int nRotation, int nPosX, int nPosY)
{
    foreach (ref px; 0 .. 4)
        foreach (ref py; 0 .. 4)
        {
            const pIndex = rotate(px, py, nRotation);  // index piece
            const fIndex = (nPosY + py) * nFieldWidth + (nPosX + px);  // index field

            if (((nPosX + px) >= 0 && (nPosX + px) < nFieldWidth) &&  // collides with lateral boundaries
                ((nPosY + py) >= 0 && (nPosY + py) < nFieldHeight) &&  // collides at the upper and lower limits	
                (tetromino[nTetromino][pIndex] == 'X') &&  // it's a piece
				(pField[fIndex] != 0))  // it's not an empty field space
            {
                return false;
            }
        }

    return true;
}

void main()
{
    wchar[nScreenWidth * nScreenHeight] screen = ' ';  // all screen = ' '

	auto hConsole = CreateConsoleScreenBuffer(
		GENERIC_READ | GENERIC_WRITE,
		0,
		NULL,
		CONSOLE_TEXTMODE_BUFFER,
		NULL
	);

	SetConsoleActiveScreenBuffer(hConsole);
	uint dwBytesWritten = 0;    

    foreach (int x; 0 .. nFieldWidth)
        foreach (int y; 0 .. nFieldHeight)
			if ( x == 0 || x == nFieldWidth - 1 || y == nFieldHeight - 1) // border condition
            	pField[y * nFieldWidth + x] = 9;  // setting borders of the field
				
    bool[4] bKey;

	int nCurrentPiece,
		nCurrentRotation,
		nCurrentX = nFieldWidth / 2,
		nCurrentY,
		nSpeedCount,
		nPieceCount,
		nScore,
		nSpeed = 20,
		nTotalLines,
		nNextPiece;

	bool bForceDown,
		bGameOver,
		bRotateHold = true;

	int[] vLines;

	// Get next piece
	nCurrentPiece = rndGen.front % 7;
	rndGen.popFront;
	nNextPiece = rndGen.front % 7;
	rndGen.popFront;	

	while (!bGameOver)
	{
		// GAME TIMMING
		Thread.sleep( 50.msecs );  // Game tick
		nSpeedCount++;
		bForceDown = (nSpeedCount == nSpeed);

		// GAME INPUT
		foreach (i; 0..4)									//  R	L	D Z
			bKey[i] = (0x8000 & GetAsyncKeyState(cast(ubyte)("\x27\x25\x28Z"[i]))) != 0;  // true for pressed key

		// GAME LOGIC
		nCurrentX += (bKey[0] && doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX + 1, nCurrentY)) ? 1 : 0;  // move nCurrentX to right 1 position
		nCurrentX -= (bKey[1] && doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX - 1, nCurrentY)) ? 1 : 0;  // move nCurrentX to left 1 position	
		nCurrentY += (bKey[2] && doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX, nCurrentY + 1)) ? 1 : 0;	// move nCurrentY to down 1 position

		if (bKey[3])
		{
			nCurrentRotation += (bRotateHold && doesPieceFit(nCurrentPiece, nCurrentRotation + 1, nCurrentX, nCurrentY)) ? 1 : 0;
			bRotateHold = false;
		}
		else
			bRotateHold = true;

		if (bForceDown)
		{
			nSpeedCount = int.init;
			nPieceCount++;
			if (!(nPieceCount % 50))
				if (nSpeed >= 10) 
					nSpeed--;

			if (doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX, nCurrentY + 1))
				nCurrentY++;
			else
			{
				foreach (x; 0..4)
					foreach (y; 0..4)
						if (tetromino[nCurrentPiece][rotate(x, y, nCurrentRotation)] != '.')
							pField[(nCurrentY + y) * nFieldWidth + (nCurrentX + x)] = cast(char)(nCurrentPiece + 1);

				foreach (y; 0..4)
					if (nCurrentY + y < nFieldHeight - 1)
					{
						bool bLine = true;
						foreach (x; 1..(nFieldWidth - 1))
							bLine &= (pField[(nCurrentY + y) * nFieldWidth + x]) != 0;

						if (bLine)
						{
							foreach (x; 1..(nFieldWidth - 1))
								pField[(nCurrentY + y) * nFieldWidth + x] = 8;
							vLines ~= (nCurrentY + y);
						}
					}

				nScore += 25;
				if (vLines.length != 0)
					nScore += (1 << vLines.length) * 100;

				nCurrentX = nFieldWidth / 2;
				nCurrentY = int.init;
				nCurrentRotation = int.init;
				nCurrentPiece = nNextPiece;
				nNextPiece = rndGen.front % 7;
				rndGen.popFront;

				bGameOver = !doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX, nCurrentY);				
			}

		}


		// GAME RENDER
		// Draw field
		foreach (x; 0..nFieldWidth)
			foreach (y; 0..nFieldHeight)
				screen[(y + 2)*nScreenWidth + (x + 2)] = " ABCDEFG=#"[pField[y*nFieldWidth + x]];

		// Draw Current Piece
		foreach (px; 0..4)
			foreach (py; 0..4)
				if (tetromino[nCurrentPiece][rotate(px, py, nCurrentRotation)] != '.')
					screen[(nCurrentY + py + 2)*nScreenWidth + (nCurrentX + px + 2)] = cast(wchar)(nCurrentPiece + 65);

		// Draw Score
		swprintf(&screen[2 * nScreenWidth + nFieldWidth + 6], 16, "SCORE: %8d", nScore);

		// Draw Total Lines
		swprintf(&screen[4 * nScreenWidth + nFieldWidth + 6], 16, "LINES: %8d", nTotalLines);

		// Draw Next Piece
		swprintf(&screen[7 * nScreenWidth + nFieldWidth + 6], 16, "NEXT:");

		// Next Piece
		foreach (px; 0..4)
			foreach (py; 0..4) 
				screen[(6 + py) * nScreenWidth + nFieldWidth + px + 16] = 
				tetromino[nNextPiece][rotate(px, py, 0)] != '.' ? 
				cast(wchar)(nNextPiece + 65) :
				' ';

		// Animate Line Completion
		if (vLines.length != 0)
		{
			// Display Frame (cheekily to draw lines)
			WriteConsoleOutputCharacter(hConsole, screen.ptr, nScreenWidth * nScreenHeight, COORD(0, 0), &dwBytesWritten);
			Thread.sleep( 400.msecs ); // Delay a bit

			foreach (ref v; vLines)
				foreach (px; 1..(nFieldWidth - 1))
				{
					foreach_reverse (py; 1..v+1)
						pField[py * nFieldWidth + px] = pField[(py - 1) * nFieldWidth + px];
					pField[px] = 0;
				}

			nTotalLines += vLines.length;
			vLines.length = 0;
		}

		// Display Frame
		WriteConsoleOutputCharacter(hConsole, screen.ptr, nScreenWidth * nScreenHeight, COORD(0, 0), &dwBytesWritten);
	}

	CloseHandle(hConsole);
	writeln("Game Over!! Score:", nScore);
	readln;   
}
