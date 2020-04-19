import std.stdio;
import core.time;
import core.thread;
import core.stdc.wchar_;
import core.sys.windows.windows;
import std.random;

enum nFieldWidth = 12;
enum nFieldHeight = 18;
enum nScreenWidth = 120;
enum nScreenHeight = 30;

string[7] tetromino;
char[nFieldWidth * nFieldHeight] pField;

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

bool doesPieceFit(int nTetromino, int nRotation, int nPosX, int nPosY)
{
    foreach (ref px; 0 .. 4)
        foreach (ref py; 0 .. 4)
        {
            int pIndex = rotate(px, py, nRotation);

            int fIndex = (nPosY + py) * nFieldWidth + (nPosX + px);

            if (((nPosX + px) >= 0 && (nPosX + px) < nFieldWidth) &&
                ((nPosY + py) >= 0 && (nPosY + py) < nFieldHeight) &&
                (tetromino[nTetromino][pIndex] != '.' && pField[fIndex] != 0))
            {
                return false;
            }
        }

    return true;
}

void main()
{
    wchar[nScreenWidth * nScreenHeight] screen;

    foreach(ref c; screen)
		c = ' ';

	auto hConsole = CreateConsoleScreenBuffer(
		GENERIC_READ | GENERIC_WRITE,
		0,
		NULL,
		CONSOLE_TEXTMODE_BUFFER,
		NULL
	);
	SetConsoleActiveScreenBuffer(hConsole);
	uint dwBytesWritten = 0;    

	tetromino[0] = "..X...X...X...X.";
	tetromino[1] = "..X..XX...X.....";
	tetromino[2] = ".....XX..XX.....";
	tetromino[3] = "..X..XX..X......";
	tetromino[4] = ".X...XX...X.....";
	tetromino[5] = ".X...X...XX.....";
	tetromino[6] = "..X...X..XX.....";

    foreach (int x; 0 .. nFieldWidth)
        foreach (int y; 0 .. nFieldHeight)
            pField[y * nFieldWidth + x] = (
				x == 0 || 
				x == nFieldWidth - 1 || 
				y == nFieldHeight - 1) ? 9 : 0;
				
    bool[4] bKey;

	int nCurrentPiece,
		nCurrentRotation,
		nCurrentY,
		nSpeedCount,
		nPieceCount,
		nScore,
		nCurrentX = nFieldWidth / 2,
		nSpeed = 20;

	bool bForceDown,
		bGameOver,
		bRotateHold = true;

	int[] vLines;

	while (!bGameOver)
	{
		Thread.sleep( dur!("msecs")( 50 ));
		nSpeedCount++;
		bForceDown = (nSpeedCount == nSpeed);

		foreach (i; 0..4)
			bKey[i] = (0x8000 & GetAsyncKeyState(cast(ubyte)("\x27\x25\x28Z"[i]))) != 0;

		nCurrentX += (bKey[0] && doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX + 1, nCurrentY)) ? 1 : 0;
		nCurrentX -= (bKey[1] && doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX - 1, nCurrentY)) ? 1 : 0;		
		nCurrentY += (bKey[2] && doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX, nCurrentY + 1)) ? 1 : 0;

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
				nCurrentPiece = rndGen.front % 7;
				rndGen.popFront;

				bGameOver = !doesPieceFit(nCurrentPiece, nCurrentRotation, nCurrentX, nCurrentY);				
			}

		}

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

		// Animate Line Completion
		if (vLines.length != 0)
		{
			// Display Frame (cheekily to draw lines)
			WriteConsoleOutputCharacter(hConsole, screen.ptr, nScreenWidth * nScreenHeight, COORD(0, 0), &dwBytesWritten);
			Thread.sleep(dur!("msecs")(400)); // Delay a bit

			foreach (ref v; vLines)
				foreach (px; 1..(nFieldWidth - 1))
				{
					foreach_reverse (py; 1..v+1)
						pField[py * nFieldWidth + px] = pField[(py - 1) * nFieldWidth + px];
					pField[px] = 0;
				}

			vLines.length = 0;
		}

		// Display Frame
		WriteConsoleOutputCharacter(hConsole, screen.ptr, nScreenWidth * nScreenHeight, COORD(0, 0), &dwBytesWritten);
	}

	CloseHandle(hConsole);
	writeln("Game Over!! Score:", nScore);
	readln();   
}
