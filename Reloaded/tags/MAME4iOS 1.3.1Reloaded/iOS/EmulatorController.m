/*
 * This file is part of MAME4iOS.
 *
 * Copyright (C) 2013 David Valdeita (Seleuco)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses>.
 *
 * Linking MAME4iOS statically or dynamically with other modules is
 * making a combined work based on MAME4iOS. Thus, the terms and
 * conditions of the GNU General Public License cover the whole
 * combination.
 *
 * In addition, as a special exception, the copyright holders of MAME4iOS
 * give you permission to combine MAME4iOS with free software programs
 * or libraries that are released under the GNU LGPL and with code included
 * in the standard release of MAME under the MAME License (or modified
 * versions of such code, with unchanged license). You may copy and
 * distribute such a system following the terms of the GNU GPL for MAME4iOS
 * and the licenses of the other code concerned, provided that you include
 * the source code of that other code when and as the GNU GPL requires
 * distribution of source code.
 *
 * Note that people who make modified versions of MAME4iOS are not
 * obligated to grant this special exception for their modified versions; it
 * is their choice whether to do so. The GNU General Public License
 * gives permission to release a modified version without this exception;
 * this exception also makes it possible to release a modified version
 * which carries forward this exception.
 *
 * MAME4iOS is dual-licensed: Alternatively, you can license MAME4iOS
 * under a MAME license, as set out in http://mamedev.org/
 */

#include "myosd.h"
#import "EmulatorController.h"
#import "ScreenView.h"
#import "HelpController.h"
#import "OptionsController.h"
#import "DonateController.h"
#import "iCadeView.h"
#import "DebugView.h"
#import "AnalogStick.h"
#ifdef WIIMOTE
#import "WiiMoteHelper.h"
#endif
#import <pthread.h>

int g_isIpad = 0;
int g_isIphone5 = 0;

int g_emulation_paused = 0;
int g_emulation_initiated=0;

int g_joy_used = 0;
int g_iCade_used = 0;
#ifdef WIIMOTE
int g_wiimote_avalible = 1;
#else
int g_wiimote_avalible = 0;
#endif
int g_menu_option = MENU_NONE;

int g_enable_debug_view = 0;
int g_controller_opacity = 50;

int g_device_is_landscape = 0;

int g_pref_smooth_land = 0;
int g_pref_smooth_port = 0;
int g_pref_keep_aspect_ratio_land = 0;
int g_pref_keep_aspect_ratio_port = 0;

int g_pref_tv_filter_land = 0;
int g_pref_tv_filter_port = 0;

int g_pref_scanline_filter_land = 0;
int g_pref_scanline_filter_port = 0;

int g_pref_animated_DPad = 0;
int g_pref_4buttonsLand = 0;
int g_pref_full_screen_land = 1;
int g_pref_full_screen_port = 1;

int g_pref_hide_LR=0;
int g_pref_BplusX=0;
int g_pref_full_num_buttons=4;
int g_pref_skin = 1;
int g_pref_wii_DZ_value = 2;
int g_pref_touch_DZ = 1;

int g_pref_input_touch_type = TOUCH_INPUT_DSTICK;
int g_pref_analog_DZ_value = 2;
int g_pref_ext_control_type = 1;

int g_pref_aplusb = 0;

int g_pref_nativeTVOUT = 1;
int g_pref_overscanTVOUT = 1;

int global_low_latency_sound = 0;
static int main_thread_priority = 46;
int video_thread_priority = 46;
static int main_thread_priority_type = 1;
int video_thread_priority_type = 1;

        
static pthread_t main_tid;

static int skin_data = 1;
static int enable_menu_exit_option = 0;
static int actionPending=0;
static int wantExit = 0;
static int old_pref_num_buttons = 0;
static int old_filter_manufacturer = 0;
static int old_filter_gte_year = 0;
static int old_filter_lte_year = 0;
static int old_filter_driver_source = 0;
static int old_filter_category = 0;
static int old_myosd_num_buttons = 0;
static int button_auto = 0;
static int ways_auto = 0;

static EmulatorController *sharedInstance = nil;
	
void iphone_Reset_Views(void)
{
   if(sharedInstance==nil) return;
#ifndef JAILBREAK
   if(!myosd_inGame)
      [sharedInstance performSelectorOnMainThread:@selector(moveROMS) withObject:nil waitUntilDone:NO];
#endif
   [sharedInstance performSelectorOnMainThread:@selector(changeUI) withObject:nil waitUntilDone:NO];  
}

void* app_Thread_Start(void* args)
{
	g_emulation_initiated = 1;
	
	iOS_main(0,NULL);

	return NULL;
}

@implementation UINavigationController(KeyboardDismiss)

- (BOOL)disablesAutomaticKeyboardDismissal
{
    return NO;
}

@end

@implementation EmulatorController

@synthesize dpad_state;
@synthesize num_debug_rects;
@synthesize externalView;
@synthesize rExternalView;
@synthesize stick_radio;
@synthesize rStickArea;

- (int *)getBtnStates{
    return btnStates;
}

- (void)startEmulation{
    
    sharedInstance = self;
	     		    				
    pthread_create(&main_tid, NULL, app_Thread_Start, NULL);
		
	struct sched_param param;
 
    //param.sched_priority = 67;
    //param.sched_priority = 50;
    //param.sched_priority = 46;  
    //param.sched_priority = 100;
    param.sched_priority = main_thread_priority;
    int policy;
    if(main_thread_priority_type == 1)
      policy = SCHED_OTHER;
    else if(main_thread_priority_type == 2)
      policy = SCHED_RR;
    else
      policy = SCHED_FIFO;
           
    if(pthread_setschedparam(main_tid, policy, &param) != 0)    
             fprintf(stderr, "Error setting pthread priority\n");
    	
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{	
	if(buttonIndex == 999)
    {
        return;
    }
    
    int loadsave = myosd_inGame * 2;
  
    
    if(buttonIndex == 0 && enable_menu_exit_option)
    {
       g_menu_option = MENU_EXIT;
       myosd_exitGame = 0;
       wantExit = 1;	            
       UIAlertView* exitAlertView=[[UIAlertView alloc] initWithTitle:nil
                                                              message:@"are you sure you want to exit the game?"
                                                             delegate:self cancelButtonTitle:nil
                                                    otherButtonTitles:@"Yes",@"No",nil];                                                        
       [exitAlertView show];
       [exitAlertView release];           
       
    }   
    else if((buttonIndex == 0 && !enable_menu_exit_option && loadsave) || (buttonIndex == 1 && enable_menu_exit_option && loadsave))
    {
       myosd_loadstate = 1;
       [self endMenu];
    }
    else if((buttonIndex == 1 && !enable_menu_exit_option && loadsave) || (buttonIndex == 2 && enable_menu_exit_option && loadsave))
    {
       myosd_savestate = 1;
       [self endMenu];
    }     
    else if(buttonIndex == 0 + enable_menu_exit_option + loadsave)
    {
       g_menu_option = MENU_OPTIONS;
       
       OptionsController *addController =[[OptionsController alloc] init];
        
       addController.emuController = self;
                               
       UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:addController] autorelease];
        
       //[navController setModalPresentationStyle: /*UIModalPresentationFormSheet*/ UIModalPresentationPageSheet];
        
       [self presentModalViewController:navController animated:YES];
        
       //[self presentModalViewController:addController animated:YES];

       [addController release];
    }
#ifdef WIIMOTE
    else if(buttonIndex == 1 + enable_menu_exit_option + loadsave)
    {
       g_menu_option = MENU_WIIMOTE;

       [WiiMoteHelper startwiimote:self];
    }
#endif    
    else   	    
    {
       [self endMenu];
    }
  	      
    [menu release];
    menu = nil;
                          
}

- (void)runMenu
{
    if(g_menu_option != MENU_NONE)
       return;

    if(menu!=nil)
    {
       [menu dismissWithClickedButtonIndex:999 animated:YES];
       [menu release];
       menu = nil;
    }
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;

    actionPending=1;
        
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    g_emulation_paused = 1;
    change_pause(1);
  
    enable_menu_exit_option  = g_iCade_used && myosd_inGame && myosd_in_menu==0;
    
    menu = [[UIActionSheet alloc] initWithTitle:
            @"Choose an option from the menu. Press cancel to go back." delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil
                              otherButtonTitles: nil];
    
    if(enable_menu_exit_option)
       [menu addButtonWithTitle:@"Exit Game"];
    if(myosd_inGame)
    {
       [menu addButtonWithTitle:@"Load State"];
       [menu addButtonWithTitle:@"Save State"];
    }
    [menu addButtonWithTitle:@"Settings"];
    if(g_wiimote_avalible)
       [menu addButtonWithTitle:@"WiiMote"];
    [menu addButtonWithTitle:@"Cancel"];
    	   
    [menu showInView:self.view];
	   
    [pool release];      
}

- (void)endMenu{
	  	
	  int old = g_joy_used;
	  g_joy_used = myosd_num_of_joys!=0;
	    
	  if(((!g_device_is_landscape && g_pref_full_screen_port) || (g_device_is_landscape && g_pref_full_screen_land)) && g_joy_used && old!=g_joy_used)
	  {
	      [self changeUI]; 
	  }
	  if(((!g_device_is_landscape && g_pref_full_screen_port) || (g_device_is_landscape && g_pref_full_screen_land)) && !g_joy_used && old!=g_joy_used)
	  { 
	      [self changeUI];
	  }
	    
	  actionPending=0;
	  myosd_exitPause = 1;
      g_emulation_paused = 0;
      change_pause(0);
      g_menu_option = MENU_NONE;
    

      iCade.active = FALSE;
      if(g_pref_ext_control_type != EXT_CONTROL_NONE)
      {
         iCade.active = TRUE;//force renable
      }
      else if(g_iCade_used)//ensure is off
      {
          g_iCade_used = 0;
          g_joy_used = 0;
          myosd_num_of_joys = 0;
          [self changeUI];
      }
    
      [UIApplication sharedApplication].idleTimerDisabled = (myosd_inGame || g_joy_used) ? YES : NO;//so atract mode dont sleep
}

-(void)updateOptions{
    
    Options *op = [[Options alloc] init];
    
    g_pref_keep_aspect_ratio_land = [op keepAspectRatioLand];
    g_pref_keep_aspect_ratio_port = [op keepAspectRatioPort];
    g_pref_smooth_land = [op smoothedLand];
    g_pref_smooth_port = [op smoothedPort];
    
    g_pref_tv_filter_land = [op tvFilterLand];
    g_pref_tv_filter_port = [op tvFilterPort];
    
    g_pref_scanline_filter_land = [op scanlineFilterLand];
    g_pref_scanline_filter_port = [op scanlineFilterPort];
    
    myosd_fps = [op showFPS];
    myosd_showinfo =  isGridlee ? 0 : [op showINFO];
    g_pref_animated_DPad  = [op animatedButtons];
    g_pref_full_screen_land  = isGridlee ? 0 : [op fullLand];
    g_pref_full_screen_port  = [op fullPort];
    
    myosd_pxasp1 = [op p1aspx];
    
    g_pref_skin = [op skinValue]+1;
    skin_data = g_pref_skin;
    if(g_pref_skin == 2 && g_isIpad)
        g_pref_skin = 3;
    
    g_pref_wii_DZ_value = [op wiiDeadZoneValue];
    g_pref_touch_DZ = [op touchDeadZone];
    
    g_pref_nativeTVOUT = [op tvoutNative];
    g_pref_overscanTVOUT = [op overscanValue];
    
    g_pref_input_touch_type = isGridlee ? 0 : [op touchtype];
    g_pref_analog_DZ_value = [op analogDeadZoneValue];
    g_pref_ext_control_type = [op controltype];
    
    switch  ([op soundValue]){
        case 0: myosd_sound_value=-1;break;
        case 1: myosd_sound_value=11025;break;
        case 2: myosd_sound_value=22050;break;
        case 3: myosd_sound_value=32000;break;
        case 4: myosd_sound_value=44100;break;
        case 5: myosd_sound_value=48000;break;
        default:myosd_sound_value=-1;}
    
    myosd_throttle = [op throttle];
    myosd_cheat = [op cheats];
    myosd_sleep = [op sleep];
    
    old_pref_num_buttons = [op numbuttons];
    g_pref_aplusb = [op aplusb];
    
    int nbuttons = [op numbuttons];
    
    if(nbuttons != 0)
    {
       nbuttons = nbuttons - 1;
       if(nbuttons>4)
       {
          g_pref_hide_LR=0;
          g_pref_full_num_buttons=4;
       }
       else
       {
          g_pref_hide_LR=1;
          g_pref_full_num_buttons=nbuttons;
       }
        button_auto = 0;
    }
    else
    {
       if(myosd_num_buttons==0)
          myosd_num_buttons = 2;
    
       if(myosd_num_buttons >4)
       {
          g_pref_hide_LR=0;
          g_pref_full_num_buttons=4;
       }
       else
       {
          g_pref_hide_LR=1;
          g_pref_full_num_buttons=myosd_num_buttons;
       }
        nbuttons = myosd_num_buttons;
        old_myosd_num_buttons = myosd_num_buttons;
        button_auto = 1;
    }
    
    if([op aplusb] == 1 && nbuttons==2)
    {
        g_pref_BplusX = 1;
        g_pref_full_num_buttons = 3;
        g_pref_hide_LR=1;
    }
    else
    {
        g_pref_BplusX = 0;
    }
        
    //////
    ways_auto = 0;
    if([op sticktype]==0)
    {
        ways_auto = 1;
        myosd_waysStick = myosd_num_ways;
    }
    else if([op sticktype]==1)
    {
        myosd_waysStick = 2;
    }
    else if([op sticktype]==2)
    {
        myosd_waysStick = 4;
    }
    else
    {
        myosd_waysStick = 8;
    }
    
    if([op fsvalue] == 0)
    {
        myosd_frameskip_value = -1;
    }
    else 
    {
        myosd_frameskip_value = [op fsvalue]-1;
    }
    
    myosd_force_pxaspect = [op forcepxa];
    
    myosd_res = [op emures]+1;
    
    myosd_filter_clones = op.filterClones;
    myosd_filter_favorites = op.filterFavorites;
    myosd_filter_not_working = op.filterNotWorking;
    
    old_filter_manufacturer =  op.manufacturerValue;
    old_filter_gte_year = op.yearGTEValue;
    old_filter_lte_year = op.yearLTEValue;
    old_filter_driver_source = op.driverSourceValue;
    old_filter_category = op.categoryValue;
    myosd_filter_manufacturer = op.manufacturerValue == 0 ? -1 : op.manufacturerValue -1;
    myosd_filter_gte_year = op.yearGTEValue == 0 ? -1 : op.yearGTEValue -1;
    myosd_filter_lte_year = op.yearLTEValue == 0 ? -1 : op.yearLTEValue -1;
    myosd_filter_driver_source = op.driverSourceValue == 0 ? -1 : op.driverSourceValue -1;
    myosd_filter_category = op.categoryValue == 0 ? -1 : op.categoryValue -1;
    
    if(op.filterKeyword == nil)
       myosd_filter_keyword[0] = '\0';
    else
       strcpy(myosd_filter_keyword, [op.filterKeyword UTF8String]);
    
    global_low_latency_sound = [op lowlsound];

    [op release];
}

-(void)done:(id)sender {

    [self dismissModalViewControllerAnimated:YES];

	Options *op = [[Options alloc] init];
    
/*
    if(    g_pref_smooth_port != [op smoothedPort]
        || g_pref_smooth_land != [op smoothedLand] 
        || g_pref_keep_aspect_ratio_land != [op keepAspectRatioLand]
        || g_pref_keep_aspect_ratio_port != [op keepAspectRatioPort]        
        || g_pref_tv_filter_land != [op tvFilterLand]
        || g_pref_tv_filter_port != [op tvFilterPort]
        || g_pref_scanline_filter_land != [op scanlineFilterLand]
        || g_pref_scanline_filter_port != [op scanlineFilterPort]      
        || g_pref_animated_DPad  != [op animatedButtons]
        || g_pref_full_screen_land  != [op fullLand]
        || g_pref_full_screen_port  != [op fullPort]
        || skin_data != ([op skinValue]+1)
        || g_pref_touch_DZ != [op touchDeadZone]
        || g_pref_nativeTVOUT != [op tvoutNative]
        || g_pref_overscanTVOUT != [op overscanValue]
        || g_pref_input_touch_type != [op touchtype]
        || old_pref_num_buttons != [op numbuttons]
        || g_pref_aplusb != [op aplusb]
        )
    {
       [self updateOptions]; 
*/
       
       if (g_pref_nativeTVOUT != [op tvoutNative])
       {

           UIAlertView *warnAlert = [[UIAlertView alloc] initWithTitle:@"Pending restart Application!" 
															  
 
           message:[NSString stringWithFormat: @"You need to restar for the changes to take effect"]
														 
															 delegate:self 
													cancelButtonTitle:@"Dismiss" 
													otherButtonTitles: nil];
	
	       [warnAlert show];
	       [warnAlert release];
       }
        
       if(g_pref_overscanTVOUT != [op overscanValue])
       {

           UIAlertView *warnAlert = [[UIAlertView alloc] initWithTitle:@"Pending unplug/plug TVOUT!" 
															  
 
           message:[NSString stringWithFormat: @"You need to unplug/plug TVOUT for the changes to take effect"]
														 
															 delegate:self 
													cancelButtonTitle:@"Dismiss" 
													otherButtonTitles: nil];
	
	       [warnAlert show];
	       [warnAlert release];
       }
/*
       [self performSelectorOnMainThread:@selector(changeUI) withObject:nil waitUntilDone:YES];
  
    }
*/
    
    int keyword_changed = 0;    
    if(myosd_filter_keyword[0]!='\0' && [op.filterKeyword UTF8String] != nil)
        keyword_changed = strcmp(myosd_filter_keyword,[op.filterKeyword UTF8String])!=0;
    else if(myosd_filter_keyword[0]=='\0' && [op.filterKeyword UTF8String] == nil)
        keyword_changed = 0;
    else
        keyword_changed = 1;
    
    //printf("%d %s %s\n",keyword_changed,myosd_filter_keyword,[op.filterKeyword UTF8String]);
    
    if (myosd_filter_clones != op.filterClones ||
        myosd_filter_favorites!= op.filterFavorites ||
        myosd_filter_not_working != op.filterNotWorking ||
        old_filter_manufacturer != op.manufacturerValue ||
        old_filter_gte_year != op.yearGTEValue ||
        old_filter_lte_year != op.yearLTEValue ||
        old_filter_driver_source != op.driverSourceValue ||
        old_filter_category != op.categoryValue ||
        keyword_changed
        
        )
    {
        if(!(myosd_in_menu==0 && myosd_inGame)){
            myosd_reset_filter = 1;
        }
        myosd_last_game_selected = 0;
    }
    
    if(global_low_latency_sound != [op lowlsound])
    {
        if(myosd_sound_value!=-1)
        {
           myosd_closeSound();
           global_low_latency_sound = [op lowlsound];
           myosd_openSound(myosd_sound_value, 1);
        }
    }
    
    [op release];
    
    [self updateOptions];
    
    [self performSelectorOnMainThread:@selector(changeUI) withObject:nil waitUntilDone:YES];
    
    [self endMenu];
    
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
  myosd_exitPause = 1;
  g_emulation_paused = 0;
  change_pause(0);
  if(g_menu_option == MENU_EXIT)
  {
     [self endMenu];
  }
 
  if(buttonIndex == 0 && wantExit )
  {
     myosd_exitGame = 1;
  }
  actionPending=0;
  wantExit = 0;
}

- (void)handle_MENU
{
    if(btnStates[BTN_L2] == BUTTON_PRESS && !actionPending)
    {				  				

        if(myosd_in_menu==0 && myosd_inGame)
        {
            actionPending=1;
            myosd_exitGame = 0;
            wantExit = 1;	
            usleep(100000);	            
            g_emulation_paused = 1;
            change_pause(1);
            
            UIAlertView* exitAlertView = nil;
            
            if(myosd_inGame)
	              exitAlertView=[[UIAlertView alloc] initWithTitle:nil
	                                                                  message:@"are you sure you want to exit the game?"
	                                                                 delegate:self cancelButtonTitle:nil
	                                                        otherButtonTitles:@"Yes",@"No",nil];
	                                                        	                                                        
	        [exitAlertView show];
	        [exitAlertView release];
        }
        else
        { 
            myosd_exitGame = 1;  
        }
    } 
    
    if(btnStates[BTN_R2] == BUTTON_PRESS && !actionPending)
    {
         [self runMenu];
    }					
}	

- (void)loadView {

	struct CGRect rect = [[UIScreen mainScreen] bounds];
	rect.origin.x = rect.origin.y = 0.0f;
	UIView *view= [[UIView alloc] initWithFrame:rect];
	self.view = view;
	[view release];
     self.view.backgroundColor = [UIColor blackColor];	
    externalView = nil;
    printf("loadView\n");
}

-(void)viewDidLoad{	
    printf("viewDidLoad\n");
    
   nameImgButton_NotPress[BTN_B] = @"button_NotPress_B.png";
   nameImgButton_NotPress[BTN_X] = @"button_NotPress_X.png";
   nameImgButton_NotPress[BTN_A] = @"button_NotPress_A.png";
   nameImgButton_NotPress[BTN_Y] = @"button_NotPress_Y.png";
   nameImgButton_NotPress[BTN_START] = @"button_NotPress_start.png";
   nameImgButton_NotPress[BTN_SELECT] = @"button_NotPress_select.png";
   nameImgButton_NotPress[BTN_L1] = @"button_NotPress_R_L1.png";
   nameImgButton_NotPress[BTN_R1] = @"button_NotPress_R_R1.png";
   nameImgButton_NotPress[BTN_L2] = @"button_NotPress_R_L2.png";
   nameImgButton_NotPress[BTN_R2] = @"button_NotPress_R_R2.png";
   
   nameImgButton_Press[BTN_B] = @"button_Press_B.png";
   nameImgButton_Press[BTN_X] = @"button_Press_X.png";
   nameImgButton_Press[BTN_A] = @"button_Press_A.png";
   nameImgButton_Press[BTN_Y] = @"button_Press_Y.png";
   nameImgButton_Press[BTN_START] = @"button_Press_start.png";
   nameImgButton_Press[BTN_SELECT] = @"button_Press_select.png";
   nameImgButton_Press[BTN_L1] = @"button_Press_R_L1.png";
   nameImgButton_Press[BTN_R1] = @"button_Press_R_R1.png";
   nameImgButton_Press[BTN_L2] = @"button_Press_R_L2.png";
   nameImgButton_Press[BTN_R2] = @"button_Press_R_R2.png";
         
   nameImgDPad[DPAD_NONE]=@"DPad_NotPressed.png";
   nameImgDPad[DPAD_UP]= @"DPad_U.png";
   nameImgDPad[DPAD_DOWN]= @"DPad_D.png";
   nameImgDPad[DPAD_LEFT]= @"DPad_L.png";
   nameImgDPad[DPAD_RIGHT]= @"DPad_R.png";
   nameImgDPad[DPAD_UP_LEFT]= @"DPad_UL.png";
   nameImgDPad[DPAD_UP_RIGHT]= @"DPad_UR.png";
   nameImgDPad[DPAD_DOWN_LEFT]= @"DPad_DL.png";
   nameImgDPad[DPAD_DOWN_RIGHT]= @"DPad_DR.png";
      
   dpadView=nil;
   analogStickView = nil;
      
   int i;
   for(i=0; i<NUM_BUTTONS;i++)
      buttonViews[i]=nil;
      
   screenView=nil;
   imageBack=nil;   			
   dview = nil;
   
   menu = nil;

   
   [ self getConf];

	//[self.view addSubview:self.imageBack];
 	
	//[ self getControllerCoords:0 ];
	
	//self.navigationItem.hidesBackButton = YES;
	
	
    self.view.opaque = YES;
	self.view.clearsContextBeforeDrawing = NO; //Performance?
	
	self.view.userInteractionEnabled = YES;
	
	self.view.multipleTouchEnabled = YES;
	self.view.exclusiveTouch = NO;
	
    //self.view.multipleTouchEnabled = NO; investigar porque se queda
	//self.view.contentMode = UIViewContentModeTopLeft;
	
	//[[self.view layer] setMagnificationFilter:kCAFilterNearest];
	//[[self.view layer] setMinificationFilter:kCAFilterNearest];

	//kito
	[NSThread setThreadPriority:1.0];
	
	g_menu_option = MENU_NONE;
		
	//self.view.frame = [[UIScreen mainScreen] bounds];//rMainViewFrame;
		
    [self updateOptions];
         
    [self changeUI];
    
    iCade = [[iCadeView alloc] initWithFrame:CGRectZero withEmuController:self];
    [self.view addSubview:iCade];
    
    if(g_pref_ext_control_type!=EXT_CONTROL_NONE)
       iCade.active = YES;
    
    if(0)
    {
		   UIAlertView *loadAlert = [[UIAlertView alloc] initWithTitle:nil 
	   																										
		           message:[NSString stringWithFormat: @"\n\n\nLoading.\nPlease Wait..."]
															 
																 delegate: nil 
														cancelButtonTitle: nil 
														otherButtonTitles: nil];
			   			      
		   [loadAlert show];
	       [loadAlert release];
	 }      
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
    
    [self removeDPadView];
    
    [screenView release];
    screenView = nil;
    
    [imageBack release];
    imageBack = nil;
    
    [imageOverlay release];
    imageOverlay = nil;
    
    [dview release];
    dview= nil;
    
    [iCade release];
    iCade = nil;
}

- (void)drawRect:(CGRect)rect
{
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(NSUInteger)supportedInterfaceOrientations
{
    if(isGridlee)
      return UIInterfaceOrientationMaskLandscape;
    else
      return UIInterfaceOrientationMaskAll;
}

/*
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    //printf("llaman al preferredInterfaceOrientationForPresentation\n");
    return UIInterfaceOrientationPortrait;
}
*/

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
   
    [self changeUI];
    if(menu!=nil)
    {         
         [self runMenu];
    }        
}

- (void)changeUI{
   NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
  int prev_emulation_paused = g_emulation_paused;
   
  g_emulation_paused = 1;
  change_pause(1);
  
  [self getConf];
    
  //printf("%d %d %d\n",ways_auto,myosd_num_ways,myosd_waysStick);
    
  if((ways_auto && myosd_num_ways!=myosd_waysStick) || (button_auto && old_myosd_num_buttons != myosd_num_buttons))
  {
     [self updateOptions];
  }
    
  usleep(150000);//ensure some frames displayed

  [screenView removeFromSuperview];
  [screenView release];

  if(imageBack!=nil)
  {
     [imageBack removeFromSuperview];
     [imageBack release];
     imageBack = nil;
  }
   
  //si tiene overlay
   if(imageOverlay!=nil)
   {
     [imageOverlay removeFromSuperview];
     [imageOverlay release];
     imageOverlay = nil;
   }
   
   if((self.interfaceOrientation ==  UIDeviceOrientationLandscapeLeft) || (self.interfaceOrientation == UIDeviceOrientationLandscapeRight)){
	   [self buildLandscape];	        	
   } else	if((self.interfaceOrientation == UIDeviceOrientationPortrait) || (self.interfaceOrientation == UIDeviceOrientationPortraitUpsideDown)){	
       [self buildPortrait];
   }

   //self.view.backgroundColor = [UIColor blackColor];
   [self.view setNeedsDisplay];
   	
   myosd_exitPause = 1;
	
   if(prev_emulation_paused!=1)
   {
	   g_emulation_paused = 0;
	   change_pause(0);
   }
   
   [UIApplication sharedApplication].idleTimerDisabled = (myosd_inGame || g_joy_used) ? YES : NO;//so atract mode dont sleep
    
   [pool release];
}

- (void)removeDPadView{
   
   int i;
   
   if(dpadView!=nil)
   {
      [dpadView removeFromSuperview];
      [dpadView release];
      dpadView=nil;
   }
   
   if(analogStickView!=nil)
   {
      [analogStickView removeFromSuperview];
      [analogStickView release];
      analogStickView=nil;   
   }
   
   for(i=0; i<NUM_BUTTONS;i++)
   {
      if(buttonViews[i]!=nil)
      {
         [buttonViews[i] removeFromSuperview];
         [buttonViews[i] release];     
         buttonViews[i] = nil; 
      }
   }
      
}

- (void)buildDPadView {

   int i;
   
   
   [self removeDPadView];
    
   g_joy_used = myosd_num_of_joys!=0; 
   
   if(g_joy_used && ((!g_device_is_landscape && g_pref_full_screen_port) || (g_device_is_landscape && g_pref_full_screen_land)))
     return;
   
   NSString *name;    
   
   if(g_pref_input_touch_type == TOUCH_INPUT_DPAD)
   {
	   name = [NSString stringWithFormat:@"./SKIN_%d/%@",g_pref_skin,nameImgDPad[DPAD_NONE]];
	   dpadView = [ [ UIImageView alloc ] initWithImage:[self loadImage:name]];
	   dpadView.frame = rDPad_image;
	   if( (!g_device_is_landscape && g_pref_full_screen_port) || (g_device_is_landscape && g_pref_full_screen_land))
	         [dpadView setAlpha:((float)g_controller_opacity / 100.0f)];  
	   [self.view addSubview: dpadView];
	   dpad_state = old_dpad_state = DPAD_NONE;
   }
   else
   {   
       //analogStickView
	   analogStickView = [[AnalogStickView alloc] initWithFrame:rStickWindow withEmuController:self];
	   [self.view addSubview:analogStickView];  
	   [analogStickView setNeedsDisplay];
   }
   
   for(i=0; i<NUM_BUTTONS;i++)
   {

      if(g_device_is_landscape || (!g_device_is_landscape && g_pref_full_screen_port))
      {
          if(i==BTN_Y && (g_pref_full_num_buttons < 4 || !myosd_inGame))continue;
          if(i==BTN_A && (g_pref_full_num_buttons < 3 || !myosd_inGame))continue;
          if(i==BTN_X && (g_pref_full_num_buttons < 2 && myosd_inGame))continue;
          if(i==BTN_B && (g_pref_full_num_buttons < 1 && myosd_inGame))continue;
                            
          if(i==BTN_L1 && (g_pref_hide_LR || !myosd_inGame))continue;
          if(i==BTN_R1 && (g_pref_hide_LR || !myosd_inGame))continue;
      }
       
      if(isGridlee && (i==BTN_L2 || i==BTN_R2))
          continue;
   
      //if((i==BTN_Y || i==BTN_A) && !iOS_4buttonsLand && iphone_is_landscape)
         //continue;
      name = [NSString stringWithFormat:@"./SKIN_%d/%@",g_pref_skin,nameImgButton_NotPress[i]];   
      buttonViews[i] = [ [ UIImageView alloc ] initWithImage:[self loadImage:name]];
      buttonViews[i].frame = rButton_image[i];

      if((g_device_is_landscape && (g_pref_full_screen_land /*|| i==BTN_Y || i==BTN_A*/)) || (!g_device_is_landscape && g_pref_full_screen_port))      
         [buttonViews[i] setAlpha:((float)g_controller_opacity / 100.0f)];

       if(g_device_is_landscape && !g_pref_full_screen_land && g_isIphone5 /*&& skin_data==1*/ && (i==BTN_Y || i==BTN_A || i==BTN_L1 || i==BTN_R1))
          [buttonViews[i] setAlpha:((float)g_controller_opacity / 100.0f)];
       
      [self.view addSubview: buttonViews[i]];
      btnStates[i] = old_btnStates[i] = BUTTON_NO_PRESS; 
   }
       
}

- (void)buildPortraitImageBack {

   if(!g_pref_full_screen_port)
   {
	   if(g_isIpad)
	     imageBack = [ [ UIImageView alloc ] initWithImage:[self loadImage:[NSString stringWithFormat:@"./SKIN_%d/back_portrait_iPad.png",g_pref_skin]]];
	   else
	     imageBack = [ [ UIImageView alloc ] initWithImage:[self loadImage:[NSString stringWithFormat:@"./SKIN_%d/back_portrait_iPhone.png",g_pref_skin]]];
	   
	   imageBack.frame = rFrames[PORTRAIT_IMAGE_BACK]; // Set the frame in which the UIImage should be drawn in.
	   
	   imageBack.userInteractionEnabled = NO;
	   imageBack.multipleTouchEnabled = NO;
	   imageBack.clearsContextBeforeDrawing = NO;
	   //[imageBack setOpaque:YES];
	
	   [self.view addSubview: imageBack]; // Draw the image in self.view.
   }
   
}


- (void)buildPortraitImageOverlay {
   
   if((g_pref_scanline_filter_port || g_pref_tv_filter_port) && externalView==nil)
   {
                                                                                                                                                       
       CGRect r = g_pref_full_screen_port ? rScreenView : rFrames[PORTRAIT_IMAGE_OVERLAY];
       
       UIGraphicsBeginImageContext(r.size);  
       
       //[image1 drawInRect: rPortraitImageOverlayFrame];
       
       CGContextRef uiContext = UIGraphicsGetCurrentContext();
             
       CGContextTranslateCTM(uiContext, 0, r.size.height);
	
       CGContextScaleCTM(uiContext, 1.0, -1.0);

       if(g_pref_scanline_filter_port)
       {
          UIImage *image2 = [self loadImage:[NSString stringWithFormat: @"scanline-1.png"]];
                        
          CGImageRef tile = CGImageRetain(image2.CGImage);
                   
          CGContextSetAlpha(uiContext,((float)22 / 100.0f));   
              
          CGContextDrawTiledImage(uiContext, CGRectMake(0, 0, image2.size.width, image2.size.height), tile);
       
          CGImageRelease(tile);       
       }

       if(g_pref_tv_filter_port)
       {                        
          UIImage *image3 = [self loadImage:[NSString stringWithFormat: @"crt-1.png"]];
          
          CGImageRef tile = CGImageRetain(image3.CGImage);
              
          CGContextSetAlpha(uiContext,((float)19 / 100.0f));     
          
          CGContextDrawTiledImage(uiContext, CGRectMake(0, 0, image3.size.width, image3.size.height), tile);
       
          CGImageRelease(tile);       
       }
     
       if(g_isIpad /*&& externalView==nil*/ && (!g_pref_full_screen_port /*|| 1*/))
       {
          UIImage *image1;
          if(g_isIpad)          
            image1 = [self loadImage:[NSString stringWithFormat:@"border-iPad.png"]];
          else
            image1 = [self loadImage:[NSString stringWithFormat:@"border-iPhone.png"]];
         
          CGImageRef img = CGImageRetain(image1.CGImage);
       
          CGContextSetAlpha(uiContext,((float)100 / 100.0f));  
   
          CGContextDrawImage(uiContext,rFrames[PORTRAIT_IMAGE_OVERLAY], img);
   
          CGImageRelease(img);  
       }
             
       UIImage *finishedImage = UIGraphicsGetImageFromCurrentImageContext();
                                                            
       UIGraphicsEndImageContext();
       
       imageOverlay = [ [ UIImageView alloc ] initWithImage: finishedImage];
         
       imageOverlay.frame = r;
            		    			
       [self.view addSubview: imageOverlay];
                                    
   }  

  //DPAD---   
  [self buildDPadView];   
  /////
   
  /////////////////
  if(g_enable_debug_view)
  {
	  if(dview!=nil)
	  {
	    [dview removeFromSuperview];
	    [dview release];
	  }  	 
	
	  dview = [[DebugView alloc] initWithFrame:self.view.bounds withEmuController:self];
	  
	  [self.view addSubview:dview];   
	
	  [self filldebugRects];
	  
	  [dview setNeedsDisplay];
  }
  ////////////////
}

- (void)buildPortrait {

   g_device_is_landscape = 0;
   [ self getControllerCoords:0 ];
   
   [self buildPortraitImageBack];
   
   CGRect r;
   
   if(externalView!=nil)   
   {
        r = rExternalView;
   }
   else if(!g_pref_full_screen_port)
   {
	    r = rFrames[PORTRAIT_VIEW_NOT_FULL];
   }		  
   else
   {
        r = rFrames[PORTRAIT_VIEW_FULL];
   }
   
    if(g_pref_keep_aspect_ratio_port)
    {

       int tmp_height = r.size.height;// > emulated_width ?
       int tmp_width = ((((tmp_height * myosd_vis_video_width) / myosd_vis_video_height)+7)&~7);
       		       
       if(tmp_width > r.size.width) //y no crop
       {
          tmp_width = r.size.width;
          tmp_height = ((((tmp_width * myosd_vis_video_height) / myosd_vis_video_width)+7)&~7);
       }   
       
       r.origin.x = r.origin.x + ((r.size.width - tmp_width) / 2);      
       
       if(!g_pref_full_screen_port || g_joy_used)
       {
          r.origin.y = r.origin.y + ((r.size.height - tmp_height) / 2);
       }
       else
       {
          int tmp = r.size.height - (r.size.height/5);
          if(tmp_height < tmp)                                
             r.origin.y = r.origin.y + ((tmp - tmp_height) / 2);
       }
              
       r.size.width = tmp_width;
       r.size.height = tmp_height;
   
   }  
   
   rScreenView = r;
       
   screenView = [ [ScreenView alloc] initWithFrame: rScreenView];
                  
   if(externalView==nil)
   {             		    			
      [self.view addSubview: screenView];
   }  
   else
   {   
      [externalView addSubview: screenView];
   }  
      
   [self buildPortraitImageOverlay];
     
}

- (void)buildLandscapeImageBack {

   if(!g_pref_full_screen_land)
   {
	   if(g_isIpad)
	     imageBack = [ [ UIImageView alloc ] initWithImage:[self loadImage:[NSString stringWithFormat:@"./SKIN_%d/back_landscape_iPad.png",g_pref_skin]]];
       else if(g_isIphone5)
         imageBack = [ [ UIImageView alloc ] initWithImage:[self loadImage:[NSString stringWithFormat:@"./SKIN_%d/back_landscape_iPhone_5.png",g_pref_skin]]];
	   else
	     imageBack = [ [ UIImageView alloc ] initWithImage:[self loadImage:[NSString stringWithFormat:@"./SKIN_%d/back_landscape_iPhone.png",g_pref_skin]]];
	   
	   imageBack.frame = rFrames[LANDSCAPE_IMAGE_BACK]; // Set the frame in which the UIImage should be drawn in.
	   
	   imageBack.userInteractionEnabled = NO;
	   imageBack.multipleTouchEnabled = NO;
	   imageBack.clearsContextBeforeDrawing = NO;
	   //[imageBack setOpaque:YES];
	
	   [self.view addSubview: imageBack]; // Draw the image in self.view.
   }
   
}

- (void)buildLandscapeImageOverlay{
 
   if((g_pref_scanline_filter_land || g_pref_tv_filter_land) &&  externalView==nil)
   {                                                                                                                                              
	   CGRect r;

       if(g_pref_full_screen_land)
          r = rScreenView;
       else
          r = rFrames[LANDSCAPE_IMAGE_OVERLAY];
	
	   UIGraphicsBeginImageContext(r.size);
	
	   CGContextRef uiContext = UIGraphicsGetCurrentContext();  
	   
	   CGContextTranslateCTM(uiContext, 0, r.size.height);
		
	   CGContextScaleCTM(uiContext, 1.0, -1.0);
	   
	   if(g_pref_scanline_filter_land)
	   {       	       
	      UIImage *image2;
	      
	      if(g_isIpad)
	        image2 =  [self loadImage:[NSString stringWithFormat: @"scanline-2.png"]];
	      else
	        image2 =  [self loadImage:[NSString stringWithFormat: @"scanline-1.png"]];
	                        
	      CGImageRef tile = CGImageRetain(image2.CGImage);
	      
	      if(g_isIpad)             
	         CGContextSetAlpha(uiContext,((float)10 / 100.0f));
	      else
	         CGContextSetAlpha(uiContext,((float)22 / 100.0f));
	              
	      CGContextDrawTiledImage(uiContext, CGRectMake(0, 0, image2.size.width, image2.size.height), tile);
	       
	      CGImageRelease(tile);       
	    }
	
	    if(g_pref_tv_filter_land)
	    {              
	       UIImage *image3 = [self loadImage:[NSString stringWithFormat: @"crt-1.png"]];
	          
	       CGImageRef tile = CGImageRetain(image3.CGImage);
	              
	       CGContextSetAlpha(uiContext,((float)20 / 100.0f));     
	          
	       CGContextDrawTiledImage(uiContext, CGRectMake(0, 0, image3.size.width, image3.size.height), tile);
	       
	       CGImageRelease(tile);       
	    }

	       
	    UIImage *finishedImage = UIGraphicsGetImageFromCurrentImageContext();
	                  
	    UIGraphicsEndImageContext();
	    
	    imageOverlay = [ [ UIImageView alloc ] initWithImage: finishedImage];
	    
	    imageOverlay.frame = r; // Set the frame in which the UIImage should be drawn in.
      
        imageOverlay.userInteractionEnabled = NO;
        imageOverlay.multipleTouchEnabled = NO;
        imageOverlay.clearsContextBeforeDrawing = NO;
   
        //[imageBack setOpaque:YES];
                                         
        [self.view addSubview: imageOverlay];
	  	   
    }
   
    //DPAD---   
    [self buildDPadView];   
    /////
  
   //////////////////
   if(g_enable_debug_view)
   {
	  if(dview!=nil)
	  {
        [dview removeFromSuperview];
        [dview release];
      }	 	  
	  
	  dview = [[DebugView alloc] initWithFrame:self.view.bounds withEmuController:self];
		 	  
	  [self filldebugRects];
	  
	  [self.view addSubview:dview];   
	  [dview setNeedsDisplay];
	  
	 
  }
  /////////////////	
}

- (void)buildLandscape{
	
   g_device_is_landscape = 1;
      
   [self getControllerCoords:1 ];
   
   [self buildLandscapeImageBack];
        
   CGRect r;
   
   if(externalView!=nil)
   {
        r = rExternalView;
   }
   else if(!g_pref_full_screen_land)
   {
        r = rFrames[LANDSCAPE_VIEW_NOT_FULL];
   }     
   else
   {
        r = rFrames[LANDSCAPE_VIEW_FULL];
   }     
   
   if(g_pref_keep_aspect_ratio_land)
   {
       //printf("%d %d\n",myosd_video_width,myosd_video_height);

       int tmp_width = r.size.width;// > emulated_width ?
       int tmp_height = ((((tmp_width * myosd_vis_video_height) / myosd_vis_video_width)+7)&~7);
       
       //printf("%d %d\n",tmp_width,tmp_height);
       
       if(tmp_height > r.size.height) //y no crop
       {
          tmp_height = r.size.height;
          tmp_width = ((((tmp_height * myosd_vis_video_width) / myosd_vis_video_height)+7)&~7);
       }   
       
       //printf("%d %d\n",tmp_width,tmp_height);
                
       r.origin.x = r.origin.x +(((int)r.size.width - tmp_width) / 2);             
       r.origin.y = r.origin.y +(((int)r.size.height - tmp_height) / 2);
       r.size.width = tmp_width;
       r.size.height = tmp_height;
   }
   
   rScreenView = r;
   
   screenView = [ [ScreenView alloc] initWithFrame: rScreenView];
          
   if(externalView==nil)
   {             		    			      
      [self.view addSubview: screenView];
   }  
   else
   {               
      [externalView addSubview: screenView];
   }   
           
   [self buildLandscapeImageOverlay];
	
}

////////////////


- (void)handle_DPAD{

    if(!g_pref_animated_DPad /*|| !show_controls*/)return;

    if(dpad_state!=old_dpad_state)
    {
        
       //printf("cambia depad %d %d\n",old_dpad_state,dpad_state);
       NSString *imgName; 
       imgName = nameImgDPad[dpad_state];
       if(imgName!=nil)
       {  
         NSString *name = [NSString stringWithFormat:@"./SKIN_%d/%@",g_pref_skin,imgName];   
         //printf("%s\n",[name UTF8String]);
         UIImage *img = [self loadImage: name];
         [dpadView setImage:img];
         [dpadView setNeedsDisplay];
       }           
       old_dpad_state = dpad_state;
    }
    
    int i = 0;
    for(i=0; i< NUM_BUTTONS;i++)
    {
        if(btnStates[i] != old_btnStates[i])
        {
           NSString *imgName;
           if(btnStates[i] == BUTTON_PRESS)
           {
               imgName = nameImgButton_Press[i];
           }
           else
           {
               imgName = nameImgButton_NotPress[i];
           } 
           if(imgName!=nil)
           {  
              NSString *name = [NSString stringWithFormat:@"./SKIN_%d/%@",g_pref_skin,imgName];
              UIImage *img = [self loadImage:name];
              [buttonViews[i] setImage:img];
              [buttonViews[i] setNeedsDisplay];              
           }
           old_btnStates[i] = btnStates[i]; 
        }
    }
    
}

////////////////

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	       
   
    if((g_joy_used && ((!g_device_is_landscape && g_pref_full_screen_port) || (g_device_is_landscape && g_pref_full_screen_land))))
    {
        NSSet *allTouches = [event allTouches];
        UITouch *touch = [[allTouches allObjects] objectAtIndex:0];
        
        if(touch.phase == UITouchPhaseBegan)
		{
			[self runMenu];		
	    }
    }
    else
    {
        [self touchesController:touches withEvent:event];
    } 
}
  		
- (void)touchesController:(NSSet *)touches withEvent:(UIEvent *)event {	
    
	int i;
	static UITouch *stickTouch = nil;
    
	//Get all the touches.
	NSSet *allTouches = [event allTouches];
	int touchcount = [allTouches count];
		
	//myosd_pad_status = 0;
	myosd_pad_status &= ~MYOSD_X;
	myosd_pad_status &= ~MYOSD_Y;
	myosd_pad_status &= ~MYOSD_A;
	myosd_pad_status &= ~MYOSD_B;
	myosd_pad_status &= ~MYOSD_SELECT;
	myosd_pad_status &= ~MYOSD_START;
	myosd_pad_status &= ~MYOSD_L1;
	myosd_pad_status &= ~MYOSD_R1;
		
	for(i=0; i<NUM_BUTTONS;i++)
    {
       btnStates[i] = BUTTON_NO_PRESS; 
    }
						
	for (i = 0; i < touchcount; i++) 
	{
		UITouch *touch = [[allTouches allObjects] objectAtIndex:i];
		
		if(touch == nil)
		{
			continue;
		}
        
		if( touch.phase == UITouchPhaseBegan		||
			touch.phase == UITouchPhaseMoved		||
			touch.phase == UITouchPhaseStationary	)
		{
			struct CGPoint point;
			point = [touch locationInView:self.view];
			
			if(g_pref_input_touch_type == TOUCH_INPUT_DPAD)
			{
				if (MyCGRectContainsPoint(input[DPAD_UP_RECT], point) && !STICK2WAY) {
					//NSLog(@"MYOSD_UP");
					myosd_pad_status |= MYOSD_UP;
					dpad_state = DPAD_UP;
												    
				    myosd_pad_status &= ~MYOSD_DOWN;
				    myosd_pad_status &= ~MYOSD_LEFT;
				    myosd_pad_status &= ~MYOSD_RIGHT;		
				    
				    stickTouch = touch;		    				
				}			
				else if (MyCGRectContainsPoint(input[DPAD_DOWN_RECT], point) && !STICK2WAY) {
					//NSLog(@"MYOSD_DOWN");
					myosd_pad_status |= MYOSD_DOWN;								
					dpad_state = DPAD_DOWN;
					
				    myosd_pad_status &= ~MYOSD_UP;
				    myosd_pad_status &= ~MYOSD_LEFT;
				    myosd_pad_status &= ~MYOSD_RIGHT;				    
				    
				    stickTouch = touch;
				}			
				else if (MyCGRectContainsPoint(input[DPAD_LEFT_RECT], point)) {
					//NSLog(@"MYOSD_LEFT");
					myosd_pad_status |= MYOSD_LEFT;
					dpad_state = DPAD_LEFT;
					
				    myosd_pad_status &= ~MYOSD_UP;			    
				    myosd_pad_status &= ~MYOSD_DOWN;
				    myosd_pad_status &= ~MYOSD_RIGHT;				    
				    
				    stickTouch = touch;
				}			
				else if (MyCGRectContainsPoint(input[DPAD_RIGHT_RECT], point)) {
					//NSLog(@"MYOSD_RIGHT");
					myosd_pad_status |= MYOSD_RIGHT;
					dpad_state = DPAD_RIGHT;
					
					myosd_pad_status &= ~MYOSD_UP;			    
				    myosd_pad_status &= ~MYOSD_DOWN;
				    myosd_pad_status &= ~MYOSD_LEFT;
				    
				    stickTouch = touch;
				}			
				else if (MyCGRectContainsPoint(input[DPAD_UP_LEFT_RECT], point)) {
					//NSLog(@"MYOSD_UP | MYOSD_LEFT");
					if(!STICK2WAY && !STICK4WAY)
					{
						myosd_pad_status |= MYOSD_UP | MYOSD_LEFT;
						dpad_state = DPAD_UP_LEFT;
								    
					    myosd_pad_status &= ~MYOSD_DOWN;
					    myosd_pad_status &= ~MYOSD_RIGHT;
				    }
				    else
				    {
						myosd_pad_status |= MYOSD_LEFT;
						dpad_state = DPAD_LEFT;
								    
					    myosd_pad_status &= ~MYOSD_UP;
					    myosd_pad_status &= ~MYOSD_DOWN;
					    myosd_pad_status &= ~MYOSD_RIGHT;				    
				    }				    
				    stickTouch = touch;				
				}			
				else if (MyCGRectContainsPoint(input[DPAD_UP_RIGHT_RECT], point)) {
					//NSLog(@"MYOSD_UP | MYOSD_RIGHT");
					
					if(!STICK2WAY && !STICK4WAY)
					{
					   myosd_pad_status |= MYOSD_UP | MYOSD_RIGHT;
					   dpad_state = DPAD_UP_RIGHT;
								    
				       myosd_pad_status &= ~MYOSD_DOWN;
				       myosd_pad_status &= ~MYOSD_LEFT;
				    }
				    else
				    {
					   myosd_pad_status |= MYOSD_RIGHT;
					   dpad_state = DPAD_RIGHT;
								    
				       myosd_pad_status &= ~MYOSD_UP;
				       myosd_pad_status &= ~MYOSD_DOWN;
				       myosd_pad_status &= ~MYOSD_LEFT;				    
				    }   				    
				    stickTouch = touch;
				}			
				else if (MyCGRectContainsPoint(input[DPAD_DOWN_LEFT_RECT], point)) {
					//NSLog(@"MYOSD_DOWN | MYOSD_LEFT");

					if(!STICK2WAY && !STICK4WAY)
					{
						myosd_pad_status |= MYOSD_DOWN | MYOSD_LEFT;
						dpad_state = DPAD_DOWN_LEFT;
						
		                myosd_pad_status &= ~MYOSD_UP;			    
					    myosd_pad_status &= ~MYOSD_RIGHT;
				    }
				    else
				    {
						myosd_pad_status |= MYOSD_LEFT;
						dpad_state = DPAD_LEFT;
						
		                myosd_pad_status &= ~MYOSD_DOWN;
		                myosd_pad_status &= ~MYOSD_UP;			    
					    myosd_pad_status &= ~MYOSD_RIGHT;				    
				    }
				    stickTouch = touch;				
				}			
				else if (MyCGRectContainsPoint(input[DPAD_DOWN_RIGHT_RECT], point)) {
					//NSLog(@"MYOSD_DOWN | MYOSD_RIGHT");
					if(!STICK2WAY && !STICK4WAY)
					{
					    myosd_pad_status |= MYOSD_DOWN | MYOSD_RIGHT;
					    dpad_state = DPAD_DOWN_RIGHT;
					
	                    myosd_pad_status &= ~MYOSD_UP;			    
				        myosd_pad_status &= ~MYOSD_LEFT;
				    }
				    else
				    {    
					    myosd_pad_status |= MYOSD_RIGHT;
					    dpad_state = DPAD_RIGHT;
					
                        myosd_pad_status &= ~MYOSD_DOWN;	                    
	                    myosd_pad_status &= ~MYOSD_UP;			    
				        myosd_pad_status &= ~MYOSD_LEFT;				    
				    }
				    stickTouch = touch;
				}			
			}
            else
            {
                if(MyCGRectContainsPoint(analogStickView.frame, point) || stickTouch == touch)
                {
                    //if(stickTouch==nil)
                        stickTouch = touch;
                    //if(touch == stickTouch)
                       [analogStickView analogTouches:touch withEvent:event];
                }
            }
			
			if(touch == stickTouch) continue;
            
			if (MyCGRectContainsPoint(input[BTN_Y_RECT], point)) {
				myosd_pad_status |= MYOSD_Y;
				btnStates[BTN_Y] = BUTTON_PRESS;                
				//NSLog(@"MYOSD_Y");
			}
			else if (MyCGRectContainsPoint(input[BTN_X_RECT], point)) {
				myosd_pad_status |= MYOSD_X;
				btnStates[BTN_X] = BUTTON_PRESS;
				//NSLog(@"MYOSD_X");
			}
			else if (MyCGRectContainsPoint(input[BTN_A_RECT], point)) {
			    if(g_pref_BplusX)
			    {
					myosd_pad_status |= MYOSD_X | MYOSD_B;
	                btnStates[BTN_B] = BUTTON_PRESS;
	                btnStates[BTN_X] = BUTTON_PRESS;
	                btnStates[BTN_A] = BUTTON_PRESS;
                }
                else
                {
					myosd_pad_status |= MYOSD_A;
					btnStates[BTN_A] = BUTTON_PRESS;
				}
				//NSLog(@"MYOSD_A");
			}
			else if (MyCGRectContainsPoint(input[BTN_B_RECT], point)) {
				myosd_pad_status |= MYOSD_B;
				btnStates[BTN_B] = BUTTON_PRESS;
				//NSLog(@"MYOSD_B");
			}
			else if (MyCGRectContainsPoint(input[BTN_A_Y_RECT], point)) {
				myosd_pad_status |= MYOSD_Y | MYOSD_A;
				btnStates[BTN_Y] = BUTTON_PRESS;
				btnStates[BTN_A] = BUTTON_PRESS;
				//NSLog(@"MYOSD_Y | MYOSD_A");
			}
			else if (MyCGRectContainsPoint(input[BTN_X_A_RECT], point)) {

				myosd_pad_status |= MYOSD_X | MYOSD_A;
                btnStates[BTN_A] = BUTTON_PRESS;
                btnStates[BTN_X] = BUTTON_PRESS;
				//NSLog(@"MYOSD_X | MYOSD_A");
			}
			else if (MyCGRectContainsPoint(input[BTN_B_Y_RECT], point)) {
				myosd_pad_status |= MYOSD_Y | MYOSD_B;
                btnStates[BTN_B] = BUTTON_PRESS;
                btnStates[BTN_Y] = BUTTON_PRESS;
				//NSLog(@"MYOSD_Y | MYOSD_B");
			}			
			else if (MyCGRectContainsPoint(input[BTN_B_X_RECT], point)) {
			    if(!g_pref_BplusX /*&& g_pref_land_num_buttons>=3*/)
			    {
					myosd_pad_status |= MYOSD_X | MYOSD_B;
	                btnStates[BTN_B] = BUTTON_PRESS;
	                btnStates[BTN_X] = BUTTON_PRESS;
                }
				//NSLog(@"MYOSD_X | MYOSD_B");
			} 
			else if (MyCGRectContainsPoint(input[BTN_SELECT_RECT], point)) {
			    //NSLog(@"MYOSD_SELECT");
				myosd_pad_status |= MYOSD_SELECT;				
                btnStates[BTN_SELECT] = BUTTON_PRESS;
                if(isGridlee && (myosd_pad_status & MYOSD_START))
                    myosd_pad_status &= ~MYOSD_START;
                    
			}
			else if (MyCGRectContainsPoint(input[BTN_START_RECT], point)) {
				//NSLog(@"MYOSD_START");
				myosd_pad_status |= MYOSD_START;
			    btnStates[BTN_START] = BUTTON_PRESS;
                if(isGridlee && (myosd_pad_status & MYOSD_SELECT))
                    myosd_pad_status &= ~MYOSD_SELECT;
			}
			else if (MyCGRectContainsPoint(input[BTN_L1_RECT], point)) {
				//NSLog(@"MYOSD_L");
				myosd_pad_status |= MYOSD_L1;
			    btnStates[BTN_L1] = BUTTON_PRESS;
			}
			else if (MyCGRectContainsPoint(input[BTN_R1_RECT], point)) {
				//NSLog(@"MYOSD_R");
				myosd_pad_status |= MYOSD_R1;
				btnStates[BTN_R1] = BUTTON_PRESS;
			}			
			else if (MyCGRectContainsPoint(input[BTN_L2_RECT], point)) {
				//NSLog(@"MYOSD_L2");
                if(isGridlee)continue;
				btnStates[BTN_L2] = BUTTON_PRESS;
			}
			else if (MyCGRectContainsPoint(input[BTN_R2_RECT], point)) {
				//NSLog(@"MYOSD_R2");
				if(isGridlee)continue;
				btnStates[BTN_R2] = BUTTON_PRESS;
			}			
			else if (MyCGRectContainsPoint(input[BTN_MENU_RECT], point)) {
				/*
                myosd_pad_status |= MYOSD_SELECT;
                btnStates[BTN_SELECT] = BUTTON_PRESS;
				myosd_pad_status |= MYOSD_START;
			    btnStates[BTN_START] = BUTTON_PRESS;
                */
			}			
	        			
		}
	    else
	    {
            if(touch == stickTouch)
			{
	             if(g_pref_input_touch_type == TOUCH_INPUT_DPAD)
                 {
                    myosd_pad_status &= ~MYOSD_UP;
			        myosd_pad_status &= ~MYOSD_DOWN;
				    myosd_pad_status &= ~MYOSD_LEFT;
				    myosd_pad_status &= ~MYOSD_RIGHT;
				    dpad_state = DPAD_NONE;
                 }
                 else
                 {
                     [analogStickView analogTouches:touch withEvent:event];
                 }
				 stickTouch = nil;
		    }
	    }
	}
	
	[self handle_MENU];
	[self handle_DPAD];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	[self touchesBegan:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	[self touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[self touchesBegan:touches withEvent:event];
}

- (void)getControllerCoords:(int)orientation {
    char string[256];
    FILE *fp;
	
	if(!orientation)
	{
		if(g_isIpad)
		{
 		   if(g_pref_full_screen_port)
		     fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_portrait_full_iPad.txt", skin_data] UTF8String]];
		   else
             fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_portrait_iPad.txt", skin_data] UTF8String]];
		}
		else if(g_isIphone5)
		{
            if(g_pref_full_screen_port)
                fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_portrait_full_iPhone_5.txt", skin_data] UTF8String]];                
            else
                fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_portrait_iPhone_5.txt", skin_data] UTF8String]];
		}
		else
		{
		   if(g_pref_full_screen_port)
             fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_portrait_full_iPhone.txt", skin_data] UTF8String]];
		   else
             fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_portrait_iPhone.txt", skin_data] UTF8String]];
		}
    }
	else
	{
		if(g_isIpad)
		{
		   if(g_pref_full_screen_land)
             fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_landscape_full_iPad.txt", skin_data] UTF8String]]; 
		   else
             fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_landscape_iPad.txt", skin_data] UTF8String]]; 		  
		}
		else if(g_isIphone5)
		{
            if(g_pref_full_screen_land)
                fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_landscape_full_iPhone_5.txt", skin_data] UTF8String]];                 
            else
                fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_landscape_iPhone_5.txt", skin_data] UTF8String]];  
		}
		else
		{
		   if(g_pref_full_screen_land)
             fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_landscape_full_iPhone.txt", skin_data] UTF8String]];  
		   else
             fp = [self loadFile:[[NSString stringWithFormat:@"/SKIN_%d/controller_landscape_iPhone.txt", skin_data] UTF8String]];
		}
	}
	
	if (fp) 
	{

		int i = 0;
        while(fgets(string, 256, fp) != NULL && i < 39) 
       {
			char* result = strtok(string, ",");
			int coords[4];
			int i2 = 1;
			while( result != NULL && i2 < 5 )
			{
				coords[i2 - 1] = atoi(result);
				result = strtok(NULL, ",");
				i2++;
			}
						
			switch(i)
			{
    		case 0:    input[DPAD_DOWN_LEFT_RECT]   	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 1:    input[DPAD_DOWN_RECT]   	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 2:    input[DPAD_DOWN_RIGHT_RECT]    = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 3:    input[DPAD_LEFT_RECT]  	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 4:    input[DPAD_RIGHT_RECT]  	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 5:    input[DPAD_UP_LEFT_RECT]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 6:    input[DPAD_UP_RECT]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 7:    input[DPAD_UP_RIGHT_RECT]  	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 8:    input[BTN_SELECT_RECT] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 9:    input[BTN_START_RECT]  = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 10:   input[BTN_L1_RECT]   = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 11:   input[BTN_R1_RECT]   = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 12:   input[BTN_MENU_RECT]   = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 13:   input[BTN_X_A_RECT]   	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 14:   input[BTN_X_RECT]   	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 15:   input[BTN_B_X_RECT]    	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 16:   input[BTN_A_RECT]  		= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 17:   input[BTN_B_RECT]  	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 18:   input[BTN_A_Y_RECT]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 19:   input[BTN_Y_RECT]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 20:   input[BTN_B_Y_RECT]  	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 21:   input[BTN_L2_RECT]   = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 22:   input[BTN_R2_RECT]   = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
    		case 23:    break;
    		
    		case 24:   rButton_image[BTN_B] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 25:   rButton_image[BTN_X]  = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 26:   rButton_image[BTN_A]  = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 27:   rButton_image[BTN_Y]  = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 28:   rDPad_image  = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 29:   rButton_image[BTN_SELECT]  = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 30:   rButton_image[BTN_START]  = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 31:   rButton_image[BTN_L1] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 32:   rButton_image[BTN_R1] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 33:   rButton_image[BTN_L2] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 34:   rButton_image[BTN_R2] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            
            case 35:   rStickWindow = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 36:   rStickArea = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
            case 37:   stick_radio =coords[0]; break;            
            case 38:   g_controller_opacity= coords[0]; break;
			}
      i++;
    }
    fclose(fp);
    
    if(g_pref_touch_DZ)
    {
        //ajustamos
        if(!g_isIpad)
        {
           if(!orientation)
           {
             input[DPAD_LEFT_RECT].size.width -= 17;//Left.size.width * 0.2;
             input[DPAD_RIGHT_RECT].origin.x += 17;//Right.size.width * 0.2;
             input[DPAD_RIGHT_RECT].size.width -= 17;//Right.size.width * 0.2;
           }
           else
           {
             input[DPAD_LEFT_RECT].size.width -= 14;
             input[DPAD_RIGHT_RECT].origin.x += 20;
             input[DPAD_RIGHT_RECT].size.width -= 20;
           }
        }
        else
        {
           if(!orientation)
           {
             input[DPAD_LEFT_RECT].size.width -= 22;//Left.size.width * 0.2;
             input[DPAD_RIGHT_RECT].origin.x += 22;//Right.size.width * 0.2;
             input[DPAD_RIGHT_RECT].size.width -= 22;//Right.size.width * 0.2;
           }
           else
           {
             input[DPAD_LEFT_RECT].size.width -= 22;
             input[DPAD_RIGHT_RECT].origin.x += 22;
             input[DPAD_RIGHT_RECT].size.width -= 22;
           }
        }    
    }
  }
}

- (void)getConf{
    char string[256];
    FILE *fp;
	
	if(g_isIpad)
       fp = [self loadFile:"config_iPad.txt"];
    else if(g_isIphone5)
       fp = [self loadFile:"config_iPhone_5.txt"];
	else
	   fp = [self loadFile:"config_iPhone.txt"];
	   	
	if (fp) 
	{

		int i = 0;
        while(fgets(string, 256, fp) != NULL && i < 14)
       {
			char* result = strtok(string, ",");
			int coords[4];
			int i2 = 1;
			while( result != NULL && i2 < 5 )
			{
				coords[i2 - 1] = atoi(result);
				result = strtok(NULL, ",");
				i2++;
			}
						
			switch(i)
			{
	    		case 0:    rFrames[PORTRAIT_VIEW_FULL]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
	    		case 1:    rFrames[PORTRAIT_VIEW_NOT_FULL] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
	    		case 2:    rFrames[PORTRAIT_IMAGE_BACK]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
	    		case 3:    rFrames[PORTRAIT_IMAGE_OVERLAY]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
	    		
                case 4:    rFrames[LANDSCAPE_VIEW_FULL] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
	    		case 5:    rFrames[LANDSCAPE_VIEW_NOT_FULL] = CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
	    		case 6:    rFrames[LANDSCAPE_IMAGE_BACK]  	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
	    		case 7:    rFrames[LANDSCAPE_IMAGE_OVERLAY]     	= CGRectMake( coords[0], coords[1], coords[2], coords[3] ); break;
                    
	            case 8:    g_enable_debug_view = coords[0]; break;
	            case 9:    myosd_video_threaded = coords[0]; break;
	            case 10:   main_thread_priority = coords[0]; break;
	            case 11:   video_thread_priority = coords[0]; break;
	            case 12:   main_thread_priority_type = coords[0]; break;
	            case 13:   video_thread_priority_type = coords[0]; break;
			}
      i++;
    }
    fclose(fp);
  }
}


- (void)didReceiveMemoryWarning {
	//[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc {

    [self removeDPadView];

    [screenView release];
    
    [imageBack release];
      
    [imageOverlay release];
 
    [dview release];
    
    [iCade release];
	   
	[super dealloc];
}

- (CGRect *)getDebugRects{
    return debug_rects;
}

- (void)filldebugRects {

	    	debug_rects[0]=input[BTN_X_A_RECT];
	    	debug_rects[1]=input[BTN_X_RECT];
	    	debug_rects[2]=input[BTN_B_X_RECT];
	    	debug_rects[3]=input[BTN_A_RECT];
	    	debug_rects[4]=input[BTN_B_RECT];
	    	debug_rects[5]=input[BTN_A_Y_RECT];
	    	debug_rects[6]=input[BTN_Y_RECT];
	        debug_rects[7]=input[BTN_B_Y_RECT];
    		debug_rects[8]=input[BTN_SELECT_RECT];
    		debug_rects[9]=input[BTN_START_RECT];
    		debug_rects[10]=input[BTN_L1_RECT];
    		debug_rects[11]=input[BTN_R1_RECT];
    		debug_rects[12]=input[BTN_MENU_RECT];
    		debug_rects[13]=input[BTN_L2_RECT];
    		debug_rects[14]=input[BTN_R2_RECT];
    		debug_rects[15]= CGRectZero;
    		
    		if(g_pref_input_touch_type==TOUCH_INPUT_DPAD)
    		{
				debug_rects[16]=input[DPAD_DOWN_LEFT_RECT];
				debug_rects[17]=input[DPAD_DOWN_RECT];
				debug_rects[18]=input[DPAD_DOWN_RIGHT_RECT];
				debug_rects[19]=input[DPAD_LEFT_RECT];
				debug_rects[20]=input[DPAD_RIGHT_RECT];
				debug_rects[21]=input[DPAD_UP_LEFT_RECT];
				debug_rects[22]=input[DPAD_UP_RECT];
				debug_rects[23]=input[DPAD_UP_RIGHT_RECT];
	    		
	            num_debug_rects = 24;     
            }
            else
            {
  	    		debug_rects[16]=rStickWindow;
	    		debug_rects[17]=rStickArea;
	    		
	            num_debug_rects = 18;
            }   
}

- (UIImage *)loadImage:(NSString *)name{
    
    NSString *path = nil;
    UIImage *img = nil;
    
    path=[NSString stringWithUTF8String:get_documents_path((char *)[name UTF8String])];
    
    img = [UIImage imageWithContentsOfFile:path];
    
    if(img==nil)
    {
       path=[NSString stringWithUTF8String:get_resource_path((char *)[name UTF8String])];
       img = [UIImage imageWithContentsOfFile:path];
    }
    return img;
}

-(FILE *)loadFile:(const char *)name{
    NSString *path = nil;
    FILE *fp;
    
    path = [NSString stringWithFormat:@"%s%s", get_documents_path("/"),name];
    fp = fopen([path UTF8String], "r");
    
    if(!fp)
    {
        path = [NSString stringWithFormat:@"%s%s", get_resource_path("/"),name];
        fp = fopen([path UTF8String], "r");
    }
    
    return fp;
}

-(void)moveROMS {
    NSFileManager *filemgr;
    NSArray *filelist;
    int count;
    int i;
    
    //NSLog(@"checking roms!");
    
    filemgr = [[NSFileManager alloc] init];
    
    NSString *fromPath = [NSString stringWithUTF8String:get_documents_path("")];
    filelist = [filemgr contentsOfDirectoryAtPath:fromPath error:nil];
    count = [filelist count];
    
    NSMutableArray *romlist = [[NSMutableArray alloc] init];
    for (i = 0; i < count; i++)
    {
        NSString *file = [filelist objectAtIndex: i];
        if([file isEqualToString:@"cheat.zip"])
            continue;
        if(![file hasSuffix:@".zip"])
            continue;
        [romlist addObject: file];
    }
    count = [romlist count];
    
    [filemgr release];
    
    if(count!=0)
    {
        UIAlertView *progressAlert = [[UIAlertView alloc] initWithTitle: @"Moving Newer ROMs"
                                                                message: @"Please wait..."
                                                               delegate: self
                                                      cancelButtonTitle: nil
                                                      otherButtonTitles: nil];
        UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(30.0f, 80.0f, 225.0f, 90.0f)];
        [progressAlert addSubview:progressView];
        [progressView setProgressViewStyle: UIProgressViewStyleBar];
        
        [progressAlert show];
        [progressView setProgress:0.0f];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSFileManager *filemgr = [[NSFileManager alloc] init];
            NSError *error = nil;
            int i=0;
            
            NSString *fromPath = [NSString stringWithUTF8String:get_documents_path("")];
            NSString *toPath  = [NSString stringWithUTF8String:get_documents_path("roms")];
            [NSThread sleepForTimeInterval:1.5];
            
            BOOL err = FALSE;            
            for (i = 0; i < count; i++)
            {
                NSString *romName = [romlist objectAtIndex: i];
                //NSLog(@"%@", romName);
                
                //first attemp to delete de old one
                [filemgr removeItemAtPath:[toPath stringByAppendingPathComponent:romName] error:&error];
                
                //now move it
                error = nil;
                [filemgr moveItemAtPath: [fromPath stringByAppendingPathComponent:romName]
                                 toPath: [toPath stringByAppendingPathComponent:romName]
                                  error:&error];
                if(error!=nil)
                {
                    NSLog(@"Unable to move rom: %@", [error localizedDescription]);
                    err = TRUE;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [progressView setProgress:(i / (float)count)];
                });
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressAlert dismissWithClickedButtonIndex:0 animated:YES];
                [progressAlert release];
                [progressView release];
                if(err == FALSE)
                {
                   if(!(myosd_in_menu==0 && myosd_inGame)){
                      myosd_reset_filter = 1;
                   }
                   myosd_last_game_selected = 0;
                }
            });
            
            [filemgr release];
            [romlist release];
        });
        
    }
    else
    {
        [romlist release];
    }
}

@end
