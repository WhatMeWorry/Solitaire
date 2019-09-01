
module klondike;

import std.traits;
import std.exception, std.stdio, std.process;
import std.random;
import std.algorithm;
import std.stdio;
import std.conv;
import core.stdc.stdlib;
import core.thread;

import core.sys.windows.windows;

enum    Suit : int    { heart, spade, diamond, club }
enum   Color : int    { red, black }
enum Ranking : int    { ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king }
char[2][13] symbols = [" A", " 2", " 3", " 4", " 5", " 6", " 7", " 8", " 9", "10", " J", " Q", " K"];

enum Facing : bool { down, up }

enum     priorState = "\033[0m";
		
enum     foreWhite = "\033[37m";
enum boldForeWhite = "\033[97m"; 		
enum     backWhite = "\033[47m";
enum boldBackWhite = "\033[107m"; 
		
enum     foreBlack = "\033[30m";
enum boldForeBlack = "\033[90m";
enum     backBlack = "\033[40m";
enum boldBackBlack = "\033[100m";		
		
enum       foreRed = "\033[31m";
enum   boldForeRed = "\033[91m";
enum       backRed = "\033[41m";
enum   boldBackRed = "\033[101m";	
		
enum   boldForeBlue = "\033[94m";		

HANDLE hOut;
DWORD  dwMode;

bool disableVTMode()
{
    dwMode |= !ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (!SetConsoleMode(hOut, dwMode))
    {
        return false;
    }
    return true;
}

bool EnableVTMode()
{
    // Set output mode to handle virtual terminal sequences
    hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    if (hOut == INVALID_HANDLE_VALUE)
    {
        return false;
    }

    dwMode = 0;
    if (!GetConsoleMode(hOut, &dwMode))
    {
        return false;
    }

    /+
	When writing with WriteFile or WriteConsole, characters are parsed for VT100 and similar 
    control character sequences that control cursor movement, color/font mode, and other 
    operations that can also be performed via the existing Console APIs. For more information, 
    see Console Virtual Terminal Sequences.
    +/

    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (!SetConsoleMode(hOut, dwMode))
    {
        return false;
    }
    return true;
}

void writeAndPause(string s)
{
    writeln(s);
    version(Windows)
    {  
        // pause command prints out
        // "Press any key to continue..."

        // auto ret = executeShell("pause");
        // if (ret.status == 0)
        //     writeln(ret.output);

        // The functions capture what the child process prints to both its standard output 
        // and standard error streams, and return this together with its exit code.
        // The problem is we don't have the pause return output until after the user
        // hits a key.

        writeln("Press any key to continue...");       
        executeShell("pause");  // don't bother with standard output the child returns

    }
    else // Mac OS or Linux
    {
        writeln("Press any key to continue...");
        executeShell(`read -n1 -r`);    // -p option did not work
    }
}


/+
 
 static Initialization of associative arrays is not yet implemented.  2019/7/18

int[int] suitColor = [ Suit.diamond : Color.red, 
                       Suit.spade   : Color.black, 
                       Suit.heart   : Color.red, 
                       Suit.club    : Color.black ];
+/

Color[Suit] suitColor;

struct Card
{
    Ranking  rank;
    Suit     suit;
    Color    color;
    char[2]  symbol;  
    bool     facing;  // face up or face down
}

Card[] deck;  // deck will also function as the Klondike "Stock" pile
Card[] stock;
Card[] wastePile; 


struct FoundationPile
{
    Card[] up;    // all card are face up on the Foundation
}

FoundationPile[4] foundations;



struct Pos
{
    uint x;
    uint y;
}

struct TableauPile
{
    Pos    pos; 
    Card[] down;  // face down
    Card[] up;    // face up
}

enum int Columns = 7;

TableauPile[Columns] tableau;




string s(size_t t)
{
    if(t == 1)
        return(" card");
    else
        return(" cards");
}



void placeCardsDown(size_t x)
{
    //writeln("Place ", x, s(x), " down");
    foreach(j; 0..x)
	{
		Card card;
		card = deck[$-1];  // take a card from the deck
			
        //card.facing = Facing.down;       			
        //writeln("card = ", card);
		
        //writeln("last = ", last);
        deck = deck.remove(deck.length-1);
		
        //writeln("deck length = ", deck.length);
		
        tableau[x].down ~= card;

        //tableau[x].down ~= deck.remove(deck.length);	
	}
}

void placeCardUp(size_t x)
{
    //writeln("Place 1 card up");
    //tableau[x].up[] ~= deck.remove(deck.length);
	
    Card card;
    card = deck[$-1];  // take a card from the deck

    //card.facing = Facing.up;		
    //writeln("card = ", card);

    deck = deck.remove(deck.length-1);
		
    tableau[x].up ~= card;	
}


void showTopFaceUpCards()
{
    //writeln("Cards currently face up on tableau are: ");
    foreach(size_t x, col; tableau) 
    {
        //writeln("tableau[", x, "].up[0] = ", tableau[x].up[0] );
    }		

}

void showAllFaceUpCards()
{
    //writeln("Cards currently face up on tableau area: ");
    foreach(size_t x, cardPile; tableau) 
    {
        foreach(size_t y, card; tableau[x].up)
        {
            //writeln("card is ", tableau[x].up[y] );
            //writeln("card is ", card);           			
        }
    }		

}

void displayTableau()
{
    foreach(size_t i, cardPile; tableau) 
    {
	    //writeln("cardPile = ", cardPile);

        uint r = cardPile.pos.y;
        uint c = cardPile.pos.x+1;

        if(cardPile.down.length >= 1)
        {		
            foreach(size_t j, kard; cardPile.down)
            {   
                write("\033[",to!string(r), ";", to!string(c), "H");
		        displayCard(kard);
                r++;				
            }
        }		
        if(cardPile.up.length >= 1)
        {		
            foreach(size_t j, kard; cardPile.up)
            {   
                write("\033[",to!string(r), ";", to!string(c), "H");
		        displayCard(kard);
                r++;
            }
        }
		
    }		
}


/+
struct TableauPile
{
    Pos    pos; 
    Card[] down;  // face down
    Card[] up;    // face up
}
enum int Columns = 7;
TableauPile[Columns] tableau
+/

//TableauPile column;

// https://forum.dlang.org/thread/zuzucjrbsilxxhjngwbm@forum.dlang.org?page=1


void moveTableauCardsOnOtherCards()
{
    Card fromCard;
	
    foreach(size_t x, column; tableau) 
    {
		if(tableau[x].up.length >= 1)    // is there a top card in this up pile 
        {
            fromCard = tableau[x].up[0];		
        }
	
        foreach(size_t y, possibility; tableau)
        {
		    if(x != y)  // no reason to compare card to itself
            {
                if(tableau[y].up.length >= 1)   // is there a top card in this up pile  
                {
                    if((fromCard.rank == tableau[y].up[0].rank-1) &&   // if card is one less 
                       (fromCard.color != tableau[y].up[0].color) )       // and different colors
					{
					    writeln("x = ", x, "  y = ", y);
                        writeln("tableau[y].up = ", tableau[y].up);	
                        writeln("tableau[x].up = ", tableau[x].up);
						
                        tableau[y].up ~= tableau[x].up[0..$].dup;   // move up card or cards to new up card
						                                            // concateneate dst up cards with from up cards
                                                                    // this is equivelant to physically moveing the cards

                        writeln("TAB tableau[x].up = ", tableau[x].up);					
                        tableau[x].up = tableau[x].up[0..$-1];  // remove card
                        writeln("TAB tableau[x].up = ", tableau[x].up);			
					   writeAndPause("SHRINK BY ONE");	


						writeln("x = ", x, "  y = ", y);						
						writeln("tableau[y].up = ", tableau[y].up);	
                        writeln("tableau[x].up = ", tableau[x].up);
						
                       displayTableau();						
					   writeAndPause("KYLE 3");	
                  						
						
						//tableau[x].up = tableau[x].up.remove(tableau[x].up.length-1);
                        // tableau[x].up.length = 0;	 // WRONG: just sets the length to 0. 
                        //tableau[x].up = null;  // sets both the .ptr property of an array to null, and the length to 0
                        						
                        if(tableau[x].down.length >= 1)   // Any down cards in newly exposed column?
                        {	
                            //tableau[x].up ~= tableau[x].down[$-1].dup  // WRONG WRONG WRONG						
                            tableau[x].up ~= tableau[x].down[$-1..$].dup;  // move down card into up array
                            tableau[x].down = tableau[x].down[0..$-1]; // remove the previous c							
                            //tableau[x].up[0].facing = Facing.up;

                        }
                    						
                    }
				
                }
                  				
            }
        }
 		
    }   
	
}


/+
struct TableauPile
{
    Card[] down;  // face down
    Card[] up;    // face up
}
enum int Columns = 7;
TableauPile[Columns] tableau;
+/



void displayCard(Card c)
{
	write(boldBackWhite);
	write(foreBlack);	

    if(c.facing == Facing.down)
    {
        write(boldForeBlue);
	    write(" X ");
    }
    else
	{
        if (c.color == Color.red)
            write(boldForeRed);		
        else
	        write(foreBlack);
        write(c.symbol);
        if (c.suit == Suit.diamond)
            write("\&diams;");	
        if (c.suit == Suit.heart)
            write("\&hearts;");	
        if (c.suit == Suit.club)
            write("\&clubs;");	
        if (c.suit == Suit.spade)
            write("\&spades;");	
    }
	
 	write(boldForeWhite);
	write(backBlack);	   		
}




void main()
{
    suitColor[Suit.heart]   = Color.red;
    suitColor[Suit.spade]   = Color.black;
    suitColor[Suit.diamond] = Color.red;
    suitColor[Suit.club]    = Color.black;

    foreach(i; EnumMembers!Suit) 
	{
        //writeln("enum is ", i);
        //writefln("%s: %d", i, i);
        //writeln("suitColor is ", suitColor[i]);
    }		

	
    foreach(s; EnumMembers!Suit) 
	{
        //writeln("enum is ", s);
        //writefln("%s: %d", s, s);
		
        foreach (r; EnumMembers!Ranking) 
	    {
            Card card;
            card.rank = r;
            card.symbol = symbols[r];			
            card.suit = s;        			
            if (s % 2)  
                card.color = Color.black;   // s is odd
            else
                card.color = Color.red;	
            deck ~= card;				
        }		
    }		

    //writeln("deck should have 52 cards: ", deck.length);
	
    foreach(c; deck)  
    {
        //writeln("card = ", c);
    }	

    deck = randomShuffle!(Card[])(deck);  // Shuffle the cards

    stock = deck;
	
    foreach(c; deck)  
    {
        //writeln("shuffled card = ", c);
    }	
	
    //writeln("deck should have 52 cards: ", deck.length);


    // Now deal out the Klondike Tableau
 

		
    int row = 4;
    int col = 10;		
    foreach(size_t i, table; tableau) 
    {
        table.pos.x = col;
        table.pos.y = row;
        // or
        tableau[i].pos.x = col;
        tableau[i].pos.y = row;	
        col = col + 10;		
    }   
 
 
 
    foreach(size_t x, column; tableau) 
    {
        //writeln("Column ", x);
        placeCardsDown(x);
        placeCardUp(x);       
    }   

    writeln("deck should have 24 cards: ", deck.length);

    //showTopFaceUpCards();
    
    //moveTableauCardsOnOtherCards();

    //showAllFaceUpCards();





    version (Windows)
    {
        // UTF-8 has been assigned code page numbers of 65001 at Microsoft and 1208 at IBM

        SetConsoleOutputCP(65001);

        bool fSuccess = EnableVTMode();
        if (!fSuccess) { writeln("FAILURE ***************************************"); }
		
        //switchConsoleCodePageToUTF8();
        //writeln("Résumé preparation: 10.25€");
        //writeln("\x52\&eacute;sum\u00e9 preparation: 10.25\&euro;");	
        //writeln("\x52\&eacute;sum\u00e9 preparation: 10.25\&spades;");	
        //writeln("preparation: \&spades;");

        // https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences



		
        //writeln(boldBackWhite);
        //writeln(boldForeBlack);
        //writeln(foreBlack);		
		
        //writeln("6","\&spades;");
        //writeln("J","\&clubs;");
		
        //pid = spawnShell("color 40");  // Red on white background
        //scope(exit) wait(pid);		

		
        //import std.stdio : File, stdout;
		

        //writeln(boldForeRed);
        //writeln("Q","\&hearts;");   // http://www.fileformat.info/info/unicode/char/2665/index.htm
        //writeln("K","\&diams;");	// HTML Entity (named)  &hearts;  
		
        writeln(boldForeWhite);		
        writeln(boldBackBlack);
		
        //int number;
        //readf("number:%s", &number);
		
        writeln(priorState);
		
        writeln(foreWhite);		
        writeln(backBlack);
	
	    bool suc = disableVTMode();
        if (!suc) { writeln("FAILURE ***************************************"); }	
    }

    void displayStockWasteFoundationTableauBrackets()
    {
        write(boldForeBlue);
        //write(boldBackBlack);
        write(backBlack);		
		
        string stockPos = "\033[" ~ "2" ~ ";" ~ "10" ~ "H";
		write(stockPos);
		write('[');
        write("\033[2;14H");		
	    write(']');
		
        string wastePos = "\033[2;31H";
		write(wastePos);
		write('[');
        write("\033[2;35H");		
	    write(']');		

		// foundation 1
        write("\033[","2", ";", "40", "H");		
		write('[');
        write("\033[","2", ";", "44", "H");		
	    write(']');	

		// foundation 2
        write("\033[","2", ";", "50", "H");		
		write('[');
        write("\033[","2", ";", "54", "H");		
	    write(']');	
		
		// foundation 3
        write("\033[","2", ";", "60", "H");		
		write('[');
        write("\033[","2", ";", "64", "H");		
	    write(']');	

		// foundation 4
        write("\033[","2", ";", "70", "H");		
		write('[');
        write("\033[","2", ";", "74", "H");		
	    write(']');	

        int row = 4;
		int col = 10;
        foreach( i ; tableau )
		{
		    // tableau
            write("\033[",to!string(row), ";", to!string(col), "H");		
		    write('[');
            write("\033[",to!string(row), ";", to!string(col+4), "H");		
	        write(']');
            col = col + 10;			
        }


		
    }

 
/+
012345678901234567890123456789012345678901234567890123456789012345678901234567890
    10s   +    20s  +   30s   +    40s  +    50s  +    60s  +    70s  +   80s   +

          [___]      [___]         [___]     [___]     [___]     [___]     
          stock      waste                       foundations
	
	 [___]     [___]     [___]     [___]     [___]     [___]     [___] 	 
                   tableau              tableau            tableau
+/ 
        
system("cls");		
		
		
 

 
/+ 
    int y = 1;	
    foreach(c; deck)  
    {
		write(boldBackWhite);
		write(foreBlack);	

        displayCard(c);

		y++;
		
		string moveRight = "\033[" ~ to!string(y) ~ "C";
		
		write(moveRight);
    }	
+/	
	
	auto bitBucket = executeShell("cls");
	
    // ESC [ <y> ; <x> H
    enum   cursorPos = "\033[25;25H";
    string s = "**** HELLO THERE ****";

    // system("cls");		

    displayStockWasteFoundationTableauBrackets();
	
	write(boldBackWhite);
	write(foreBlack);
	
   displayTableau();

    writeAndPause("after displayTableau");
	
    moveTableauCardsOnOtherCards();

    displayTableau();

/+
    int y = 1;	
    foreach(c; deck)  
    {
        displayCard(c);

		y++;
		
		string moveRight = "\033[" ~ to!string(y) ~ "C";
		
		write(moveRight);
    }	
+/


	

    //displayTableau();

    writeln(foreWhite);		
    writeln(backBlack);
}





















