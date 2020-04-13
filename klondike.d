

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

string stockBrackets;
string wasteBrackets;

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


Color[Suit] suitColor;

struct Card
{
    Ranking  rank;
    Suit     suit;
    Color    color;
    char[2]  symbol;  
    //bool     facing;  // face up or face down  (removed because which pile a card is in implicitly defines facing)
}

Card[] deck;  // deck will also function as the Klondike "Stock" pile
Card[] stock;
Card[] waste; 


struct FoundationPile
{
    Pos    pos;
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


void moveCursorBottomLeft()
{
    immutable string lowerLeft = "\033[" ~ "15" ~ ";" ~ "3" ~ "H";	
    writeln(lowerLeft);           
}


void writeAndPause(string s)
{

    version(Windows)
    {  
        immutable string lowerLeft = "\033[" ~ "15" ~ ";" ~ "3" ~ "H";	
        writeln(lowerLeft);        
        writeln(s);	
        writeln("Press any key to continue...");       
        executeShell("pause");  // don't bother with standard output the child returns
    }
    else // Mac OS or Linux
    {
        writeln("Press any key to continue...");
        executeShell(`read -n1 -r`);    // -p option did not work
    }
}



string s(size_t t)
{
    if(t == 1)
        return(" card");
    else
        return(" cards");
}



void placeCardsDown(size_t x)
{
    foreach(j; 0..x)
	{
		Card card;
		card = deck[$-1];  // take (copy) a card from the top (end) of the deck
			
        deck = deck[0..$-1];  // delete the card just taken
       //tableau[x].down ~= deck.remove(deck.length);	
	   
        tableau[x].down ~= card;
	}
}


void placeCardFromStockOnWasteFacingUp()
{
    Card card;
    card = deck[$-1];  // take (copy) a card from the top (end) of the deck

    waste ~= card;
	
    deck = deck[0..$-1];   // delete card just moved 
}



void placeCardUp(size_t x)
{
    //writeln("Place 1 card up");
    //tableau[x].up[] ~= deck.remove(deck.length);
	
    Card card;
    card = deck[$-1];  // take a card from the deck

    //card.facing = Facing.up;		
    //writeln("card = ", card);

    deck = deck[0..$-1];
		
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


void displayStockCard()
{
    if(stock.length >= 1)
    {
        immutable string stockCard = "\033[" ~ "2" ~ ";" ~ "17" ~ "H";	
        write(boldForeBlue);		
        write(stockCard, "X");		       
    }
}


void displayWasteCard()
{
    /+
    if(waste.length >= 1)
    {
        immutable string wasteCardPosition = "\033[" ~ "2" ~ ";" ~ "27" ~ "H";	
        write(boldForeBlue);		
        write(wasteCardPosition, "X");		       
    }
    +/
    immutable string wasteCardPosition = "\033[" ~ "2" ~ ";" ~ "26" ~ "H";	
    foreach(size_t y, kard; waste)
    {
	    write(wasteCardPosition);
        displayCard(kard, Facing.up);
        //writeln("card is ", tableau[x].up[y] );
        //writeln("card is ", card);           			
    }
}

void displayFoundation()
{
    foreach(size_t i, foundation; foundations) 
    {
        if(foundation.up.length >= 1)
        {
            uint r = foundation.pos.y;
            uint c = foundation.pos.x+1;
            write("\033[",to!string(r), ";", to!string(c), "H");
            displayCard(foundation.up[$-1], Facing.up);			
        }		
	
    }	


}


void displayTableau()
{
    system("cls");   
    displayStockWasteFoundationTableauBrackets();
	
    displayStockCard();
	
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
		        displayCard(kard, Facing.down);
                r++;				
            }
        }		
        if(cardPile.up.length >= 1)
        {		
            foreach(size_t j, kard; cardPile.up)
            {   
                write("\033[",to!string(r), ";", to!string(c), "H");
		        displayCard(kard, Facing.up);
                r++;
            }
        }
		
    }		
}



bool moveCardToFoundation()
{
    foreach(size_t i, ref column; tableau)
    {
        /+
        if(tableau[x].up.length >= 1)    // is there a top card in this up pile 
        {
            fromCard = tableau[x].up[0];		
        }
        +/
        if(column.up.length >= 1) // if there is a card in face up card column
        {

            // Card[] c = column.up[$-1..$];  // means set the c slice to same as the tableau/column slice
            //   Card c = column.up[$-1..$];  // fails correctly because c struct cant digest a slice begin..end syntax
			
            // Card[] c = column.up[$-1];     // fails because we are trying to move an element of an array into another slice   
            //   Card c = column.up[$-1];     // works because struct c gets an element.  Array indexing operation
			Suit s = column.up[$-1].suit;
            if(column.up[$-1].rank == (foundations[s].up[$-1].rank + 1))    // Even an empty foundation has a -1 valued dummy card   
            {
				moveCursorToDebugLine();
				writeln("foundations[s].up = ", foundations[s].up);			
			
                foundations[s].up ~= column.up[$-1..$];        // move (copy) card from tableau to foundation
                column.up = column.up[0..$-1];                 // delete the card just moved

                // if the up pile is empty and there is at least one down card, 
				
                if( (column.up.length == 0) && (column.down.length >= 1) )   // if up cards are all gone and there are down cards
                {		
                    column.up  ~= column.down[$-1..$].dup;  // move (copy) the down card into up slice 
                    column.down = column.down[0..$-1];      // delete the previously moved card	
                }
				
                return(true);				
            }          
        }		
    }

    return(false);
}




// TableauPile column;

// https://forum.dlang.org/thread/zuzucjrbsilxxhjngwbm@forum.dlang.org?page=1


bool moveTableauToTableauCards()
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
                if(tableau[y].up.length >= 1)   // is there a top card in this up pile  b
                {
                    //if((fromCard.rank  == tableau[y].up[0].rank-1) &&     // if card is one less 
                    //   (fromCard.color != tableau[y].up[0].color) )       // and different colors
                    if((fromCard.rank  == tableau[y].up[$-1].rank-1) &&     // if card is one less 
                       (fromCard.color != tableau[y].up[$-1].color) )       // and different colors                  
                    {
                        moveCursorToDebugLine();
                        write("x = ", x, " ");
						displayCard(fromCard, Facing.up);
                        write("  y = ", y, " ");
						displayCard(tableau[y].up[$-1], Facing.up);
                        writeAndPause("we've detected a legal move...");
                        //writeln("x = ", x, "  y = ", y);
						
                        //writeln("tableau[y].up = ", tableau[y].up);	
                        //writeln("tableau[x].up = ", tableau[x].up);
						
                        tableau[y].up ~= tableau[x].up[0..$].dup;   // move up card or cards to new up card
						                                            // concateneate dst up cards with from up cards
                                                                    // this is equivelant to physically moving the cards
                        // tableau[x].up has given up all its cards. mark as empty

                        tableau[x].up = null;           							

                        // tableau[x].up.length = 0;   // WRONG: just sets the length to 0. 
                        // tableau[x].up = null;       // sets both the .ptr property of an array to null, and the length to 0
                        						
                        if( (tableau[x].up == null) && (tableau[x].down.length >= 1) )   // if up cards are all gone and there are down cards
                        {	
                            //tableau[x].up ~= tableau[x].down[$-1].dup  // WRONG WRONG WRONG	
                            //writeln("before");			
                            //writeln("tableau[x].down = ", tableau[x].down);	
                            //writeln("tableau[x].up = ",   tableau[x].up);	
							
                            tableau[x].up  ~= tableau[x].down[$-1..$].dup;  // move down card into up array
                            tableau[x].down = tableau[x].down[0..$-1];      // remove the previous card	
							
                            //writeln("tableau[x].down = ", tableau[x].down);	
                            //writeln("tableau[x].up = ",   tableau[x].up);							
                        }
                        
                        displayTableau();
                        return(true);						
                    }				
                }                  				
            }
        }
 		
    }   
    return(false);
}



void displayCard(Card c, Facing facing)
{
	write(boldBackWhite);
	write(foreBlack);	

    if(facing == Facing.down)
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


string makeBrackets(int row, int col)
{
    immutable string doubleQuoteOct = "\042";
	
    string str = "immutable string tableauBrackets = " ~ doubleQuoteOct;
    foreach(i; 0..7)	
    {
        str ~= "\033[" ~ to!string(row) ~ ";" ~ to!string(col)   ~ "H" ~ "[" ~
               "\033[" ~ to!string(row) ~ ";" ~ to!string(col+4) ~ "H" ~ "]";
        col += 10;	
    }
    str ~= doubleQuoteOct ~ ";";       // close quote and end of statement
    return str;
}		



string makeFoundationBrackets(int row, int col)
{
    string doubleQuoteOct = "\042";
	
    string str = "immutable string foundationBrackets = " ~ doubleQuoteOct;  // immutable string foundationBrackets = "
    foreach(i; 0..4)	
    {
        str ~= "\033[" ~ to!string(row) ~ ";" ~ to!string(col)   ~ "H" ~ "[" ~
               "\033[" ~ to!string(row) ~ ";" ~ to!string(col+4) ~ "H" ~ "]";
        col += 10;	
    }
    str ~= doubleQuoteOct ~ ";";       // immutable string foundationBrackets = "ESC [2;30H
    return str;
}		



/+
012345678901234567890123456789012345678901234567890123456789012345678901234567890
    10s   +    20s  +   30s   +    40s  +    50s  +    60s  +    70s  +   80s   +

          [___]      [___]         [___]     [___]     [___]     [___]     
          stock      waste                       foundations
	
	 [___]     [___]     [___]     [___]     [___]     [___]     [___] 	 
                   tableau              tableau            tableau
+/ 



void displayStockWasteFoundationTableauBrackets()
{
    write(boldForeBlue);
    write(backBlack);	
		                                     // row       column
    immutable string stockBrackets = "\033[" ~ "2" ~ ";" ~ "15" ~ "H" ~ '[' ~ "\033[" ~ '2' ~ ';' ~ "19" ~ "H" ~ ']';		
    write(stockBrackets);		
			
    immutable string wasteBrackets = "\033[" ~ '2' ~ ';' ~ "25" ~ 'H' ~ '[' ~ "\033[" ~ '2' ~ ';' ~ "29" ~ "H" ~ ']';
    write(wasteBrackets);

    mixin(makeFoundationBrackets(2, 40));
    write(foundationBrackets);		

    mixin(makeBrackets(4, 10));
	write(tableauBrackets);	
}

void moveCursorToDebugLine()
{
		                                     // row       column
    immutable string cursorPosition = "\033[" ~ "15" ~ ";" ~ "15" ~ "H";		
    write(cursorPosition);
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
	



    foreach(size_t x, s; EnumMembers!Suit) 
	{
        Card c;
		c.rank = cast(Ranking) -1;
		c.suit = s;
        if (s % 2)  
            c.color = Color.black;   // s is odd
        else
            c.color = Color.red;			
		c.symbol = "  ";
        foundations[s].up ~= c; 
        foundations[s].pos.y = 2;
        foundations[s].pos.x = 40 + (x * 10);		
        //writeln("foundations[s].up[] is ", foundations[s].up[]);
 
    }		
       //writeAndPause("Check this out");		
 
	

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
	
	placeCardFromStockOnWasteFacingUp();
	
    writeln("deck should have 23 cards: ", deck.length);
	
	//writeAndPause("KCH");
	
	
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

        // Virtual terminal sequences are control character sequences that can control cursor movement, 
        // color/font mode, and other operations when written to the output stream. 

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










 
        
    system("cls");		
		
		
 
	
	auto bitBucket = executeShell("cls");
	
    // ESC [ <y> ; <x> H
    enum   cursorPos = "\033[25;25H";
    string s = "**** HELLO THERE ****";

    // system("cls");		
	
	//write(boldBackWhite);
	write(foreBlack);


    char key = 'a';

    while(key != 'q')
    {	
        displayTableau();	
	    displayStockCard();
	    displayWasteCard();

        bool movedCard = false;
        do
        {
            movedCard = moveTableauToTableauCards();      
        } 
        while(movedCard);
		
		
        bool movedToFound = false;
        do
        {
            movedToFound = moveCardToFoundation();      
        } 
        while(movedToFound);
        
        //moveTableauCardsOnOtherCards();
        //bool movedCard 
		
        displayTableau();	
	    displayStockCard();
	    displayWasteCard();		
        displayFoundation();		
		
        moveCursorBottomLeft();		
        write("ENTER q to quit? ");

        readf(" %s", &key);		

    }


	

    //displayTableau();

    writeln(foreWhite);		
    writeln(backBlack);



	
}


















