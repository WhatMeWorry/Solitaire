
module klondike;

import std.traits;
import std.exception, std.stdio, std.process;
import std.random;
import std.algorithm;
import std.stdio;
import std.conv;

import core.sys.windows.windows;

enum    Suit : int    { diamond, spade, heart, club }
enum   Color : int    { red, black }
enum Ranking : int    { ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king }
char[2][13] symbols = [" A", " 2", " 3", " 4", " 5", " 6", " 7", " 8", " 9", "10", " J", " Q", " K"];

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
	When writing with WriteFile or WriteConsole, characters are parsed for VT100 and similar control character sequences that control cursor movement, color/font mode, and other operations that can also be performed via the existing Console APIs. For more information, see Console Virtual Terminal Sequences.
	+/

    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (!SetConsoleMode(hOut, dwMode))
    {
        return false;
    }
    return true;
}


/+
 
 static Initialization of associative arrays is not yet implemented.  2019/7/18

int[int] suitColor = [ Suit.diamond : Color.red, 
                       Suit.spade   : Color.black, 
                       Suit.heart   : Color.red, 
                       Suit.club    : Color.black ];
+/


Color[Suit] suitColor;

FoundationPile[4] foundation;

struct Card
{
    Ranking  rank;
    Suit     suit;
    Color    color;
    char[2]  symbol;  
}

Card[] deck;  // deck will also function as the Klondike "Stock" pile

struct FoundationPile
{
    Card[] up;    // all card are face up on the Foundation
}

struct TableauPile
{
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
    writeln("Place ", x, s(x), " down");
    foreach(j; 0..x)
	{
		Card card;
		card = deck[$-1];
		
		
        writeln("card = ", card);
		
        //writeln("last = ", last);
		deck = deck.remove(deck.length-1);
		
		//writeln("deck length = ", deck.length);
		
		tableau[x].down ~= card;
		
        //tableau[x].down ~= deck.remove(deck.length);	
	}
}

void placeCardUp(size_t x)
{
    writeln("Place 1 card up");
    //tableau[x].up[] ~= deck.remove(deck.length);
	
    Card card;
    card = deck[$-1];
		
    writeln("card = ", card);

    deck = deck.remove(deck.length-1);
		
    tableau[x].up ~= card;
	
}


void showTopFaceUpCards()
{
    writeln("Cards currently face up on tableau are: ");
    foreach(size_t x, col; tableau) 
    {
        writeln("tableau[", x, "].up[0] = ", tableau[x].up[0] );
    }		

}

void showAllFaceUpCards()
{
    writeln("Cards currently face up on tableau area: ");
    foreach(size_t x, cardPile; tableau) 
    {

	    foreach(size_t y, card; tableau[x].up)
        {
            //writeln("card is ", tableau[x].up[y] );
            writeln("card is ", card);           			
		}

    }		

}



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
                    if((fromCard.rank == tableau[y].up[0].rank - 1) &&   // if card is one less 
					   (fromCard.color != tableau[y].up[0].color) )       // and different colors
					{
					    writeln("got a hit ");
					    writeln(fromCard);
					    writeln(" with ");
					    writeln(tableau[y].up[0]);

                        tableau[y].up ~= tableau[x].up[0];  // move one less pile to one more pile

                        if(tableau[x].down.length >= 1)
                        {
						     tableau[x].up ~= tableau[x].down[$-1];  // turn face up card
							 tableau[x].down.remove(tableau[x].down.length-1);
					         writeln("Turn a card up in column ", x);						 
						}						
					}
                }				         
            }
        } 		
    }   
	
}











void main()
{


    suitColor[Suit.diamond] = Color.red;
    suitColor[Suit.spade]   = Color.black;
    suitColor[Suit.heart]   = Color.red;
    suitColor[Suit.club]    = Color.black;

    foreach(i; EnumMembers!Suit) 
	{
        writeln("enum is ", i);
        writefln("%s: %d", i, i);
		writeln("suitColor is ", suitColor[i]);
    }		

	
    foreach(s; EnumMembers!Suit) 
	{
        writeln("enum is ", s);
        writefln("%s: %d", s, s);
		
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

    writeln("deck should have 52 cards: ", deck.length);
	
    foreach(c; deck)  
    {
        writeln("card = ", c);
    }	

    deck = randomShuffle!(Card[])(deck);  // Shuffle the cards

	
    foreach(c; deck)  
    {
        //writeln("shuffled card = ", c);
    }	
	
	writeln("deck should have 52 cards: ", deck.length);

    // Now deal out the Klondike Tableau
 
    foreach(size_t x, column; tableau) 
    {
        //writeln("Column ", x);
        //placeCardsDown(x);
        //placeCardUp(x);       
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
        writeln("Résumé preparation: 10.25€");
        writeln("\x52\&eacute;sum\u00e9 preparation: 10.25\&euro;");	
        writeln("\x52\&eacute;sum\u00e9 preparation: 10.25\&spades;");	
        writeln("preparation: \&spades;");

        // https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences

		enum     priorState = "\033[0m";
		
		enum      foreWhite = "\033[37m";
		enum briteForeWhite = "\033[97m"; 		
		enum      backWhite = "\033[47m";
		enum briteBackWhite = "\033[107m"; 
		
        enum      foreBlack = "\033[30m";
        enum briteForeBlack = "\033[90m";
        enum      backBlack = "\033[40m";
        enum briteBackBlack = "\033[100m";		
		
        enum        foreRed = "\033[31m";
        enum   briteForeRed = "\033[91m";
        enum        backRed = "\033[41m";
        enum   briteBackRed = "\033[101m";	

		
		writeln(briteBackWhite);
		//writeln(briteForeBlack);
		writeln(foreBlack);		
		
        writeln("6","\&spades;");
        writeln("J","\&clubs;");
		
        //pid = spawnShell("color 40");  // Red on white background
        //scope(exit) wait(pid);		

		
        //import std.stdio : File, stdout;
		

		writeln(briteForeRed);
        writeln("Q","\&hearts;");   // http://www.fileformat.info/info/unicode/char/2665/index.htm
        writeln("K","\&diams;");	// HTML Entity (named)  &hearts;  
		
        writeln(briteForeWhite);		
        writeln(briteBackBlack);
		
        //int number;
        //readf("number:%s", &number);
		
        writeln(priorState);
		
        writeln(foreWhite);		
        writeln(backBlack);
	
	    bool suc = disableVTMode();
        if (!suc) { writeln("FAILURE ***************************************"); }	

        
        
    }			
		int y = 1;	
    foreach(c; deck)  
    {
		write(briteBackWhite);
		write(foreBlack);	

        if (c.color == Color.red)
            write(briteForeRed);		
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
        //writeln("shuffled card = ", c);
		writeln();
		
		y++;
		
		string moveRight = "\033[" ~ to!string(y) ~ "C";
		
		write(moveRight);
    }	


        writeln(foreWhite);		
        writeln(backBlack);
	
}





















