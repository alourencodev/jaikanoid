#import "Basic";
#import	"Math";
#import "Window_Creation";

using Input :: #import "Input";
using Simp :: #import "Simp";

#load "config.jai";
#load "particles.jai";
#load "levels.jai";

g_window : struct
{
	window : *void;
	width : s32 = 1920;
	height : s32 = 1080;
}

Quad :: struct
{
	position : Vector2;
	size : Vector2;
}

Slab :: struct
{
	using quad : Quad;
	hp : u8 = 3;
}

// Game State
g_quit_game := false;
g_pause_game := false;
g_last_tick : float64 = 0.0;
g_current_level := 0;
g_paddle_freeze : float64 = 0.0;

// Input
g_key_left : u32;
g_key_right : u32;

// Game Objects
g_paddle := Quad.{Vector2.{0.0, PADDLE_START_HEIGHT}, PADDLE_SIZE};
g_paddle_top : float;
g_ball := Quad.{Vector2.{0.0, BALL_START_HEIGHT}, BALL_SIZE};
g_ball_direction := Vector2.{0.0, -1.0};
g_slabs : [..] Slab;

// Screen Shake
g_screen_shake_offset := Vector2.{0.0, 0.0};
g_screen_shake_timer := 0.0;

max :: (a : float, b : float) -> float
{
	if a > b then return a;
	return b;
}

min :: (a : float, b : float) -> float
{
	if a < b then return a;
	return b;
}

top :: (quad : Quad) -> float { return quad.position.y + quad.size.y; }
bottom :: (quad : Quad) -> float { return quad.position.y; }
left :: (quad : Quad) -> float { return quad.position.x; }
right :: (quad : Quad) -> float { return quad.position.x + quad.size.x; }

main :: ()
{
	// Create Window
	{
		using g_window;

		window = create_window(width, height, "Jaikanoid");
		Simp.set_render_target(window);

		width, height = Simp.get_render_dimensions(window);
	}

	g_last_tick = get_time();
	init_objects();

	while !g_quit_game
	{
		update_window_events();
		handle_inputs();
		update();
		draw();
	}
}

init_objects :: ()
{
	current_level := g_levels[g_current_level];
	using current_level;

	screen_half_width := g_window.width * 0.5;

	// Init paddle
	{
		g_paddle.size.x = current_level.paddle_width;

		paddle_half_width := g_paddle.size.x * 0.5;
		g_paddle.position.x = screen_half_width - paddle_half_width;
		g_paddle_top = top(g_paddle);

		// Freeze Paddle Movement so player doesn't accidentally start moving
		// the paddle from last level.
		g_paddle_freeze = PADDLE_FREEZE_TIME;
	}

	// Init Ball
	{
		ball_half_width := g_ball.size.x * 0.5;
		g_ball_direction = Vector2.{0.0, -1.0};
		g_ball.position.y = BALL_START_HEIGHT;
		g_ball.position.x = screen_half_width - ball_half_width;
	}

	// Init Slabs
	{
		top_margin := slab_top_margin * SLAB_HEIGHT;
		slab_start_position_y := g_window.height - top_margin;

		SLAB_TOTAL_SIDE_MARGIN :: 2 * SLAB_COUNT_SIDE_MARGIN;	// One slab per side
		slab_width := cast(float)(g_window.width / (slab_count_x + SLAB_TOTAL_SIDE_MARGIN));
		slab_start_position_x := slab_width * SLAB_COUNT_SIDE_MARGIN;

		total_slabs := slab_count_x * slab_count_y;
		array_reserve(*g_slabs, total_slabs);

		// Create Slabs
		for row : 0..(slab_count_y - 1)
		{
			for col : 0..(slab_count_x - 1)
			{
				using slab : Slab;

				slab.position.x = slab_start_position_x + (col * slab_width);
				slab.position.y = cast(float)(slab_start_position_y - (row * SLAB_HEIGHT));

				slab.size = Vector2.{slab_width, SLAB_HEIGHT};
				slab.hp = slab_max_hp;

				array_add(*g_slabs, slab);
			}
		}
	}
}

handle_inputs :: ()
{
	for event : Input.events_this_frame
	{
		if event.type == .QUIT
		{
			g_quit_game = true;
			break;
		}

		if (event.key_code == .ESCAPE) && event.key_pressed then g_pause_game = !g_pause_game;

		if event.type == .KEYBOARD
		{
			key := event.key_code;

			if key == .ARROW_LEFT then g_key_left = event.key_pressed;
			if key == .ARROW_RIGHT then g_key_right = event.key_pressed;
			if key == .ARROW_UP && event.key_pressed then array_reset(*g_slabs);
		}
	}
}

update :: ()
{
	// Update Delta Time
	now := get_time();
	delta_time := now - g_last_tick;
	g_last_tick = now;

	if g_pause_game then return;

	paddle_direction := 0;

	// Update Paddle
	{
		if g_paddle_freeze < 0
		{
			if g_key_left then paddle_direction -= 1;
			if g_key_right then paddle_direction += 1;
		}
		else
		{
			g_paddle_freeze -= delta_time;
		}

		g_paddle.position.x += cast(float)(delta_time * PADDLE_SPEED * paddle_direction);
	}

	// Update Ball position
	current_level := g_levels[g_current_level];
	g_ball.position += g_ball_direction * cast(float)(current_level.ball_speed * delta_time);

	// Paddle-Screen Boundaries
	{
		using g_paddle;

		max_paddle_position := g_window.width - size.x;

		if position.x < 0.0 then position.x = 0.0;
		if position.x > max_paddle_position then position.x = max_paddle_position;
	}

	// Paddle-Ball Collision
	if bottom(g_ball) <= g_paddle_top && top(g_ball) > g_paddle_top
	{
		PADDLE_COLLISION_MARGIN :: 4;

		if left(g_ball) <= (right(g_paddle) - PADDLE_COLLISION_MARGIN)
		{
			if right(g_ball) >= (left(g_paddle) + PADDLE_COLLISION_MARGIN)
			{
				bounce_factor := 0.6;
				paddle_ball_speed_ratio := PADDLE_SPEED / current_level.ball_speed;

				g_ball_direction.y *= -1;
				g_ball_direction.x += paddle_direction * paddle_ball_speed_ratio * bounce_factor;
				g_ball_direction = unit_vector(g_ball_direction);
				
				g_ball.position.y = g_paddle_top;
			}
		}
	}
	
	// Ball-Screen Boundaries
	{
		using g_ball;

		// Left Edge
		if position.x < 0
		{
			position.x = 0;
			g_ball_direction.x *= -1;
		}

		// Right Edge
		max_ball_x := g_window.width - size.x;
		if position.x > max_ball_x
		{
			position.x = max_ball_x;
			g_ball_direction.x *= -1;
		}

		// Top Edge
		max_ball_y := g_window.height - size.y;
		if position.y > max_ball_y
		{
			position.y = max_ball_y;
			g_ball_direction.y *= -1;
		}

		// Bottom Edge
		if position.y < 0.0
		{
			g_current_level = 0;
			g_slabs.count = 0;
			init_objects();

			return;
		}
	}

	// Ball-Slabs Collisions
	{
		new_ball_position := g_ball.position;

		has_vertical_collision := false;
		has_horizontal_collsion := false;

		ball_bottom := bottom(g_ball);
		ball_top := top(g_ball);
		ball_left := left(g_ball);
		ball_right := right(g_ball);

		for *slab : g_slabs
		{
			assert(slab.hp > 0);

			overlap_surface : Vector2;

			// Check Vertical Overlap
			slab_bottom := bottom(slab.quad);
			slab_top := top(slab.quad);
			overlap_surface.y = min(ball_top, slab_top) - max(ball_bottom, slab_bottom);
			if overlap_surface.y < 0 then continue;

			// Check Horizontal Overlap
			slab_left := left(slab.quad);
			slab_right := right(slab.quad);
			overlap_surface.x = min(ball_right, slab_right) - max(ball_left, slab_left);
			if overlap_surface.x < 0 then continue;

			// At this point we already know there is a collision

			// Test if there is a vertical or horizontal colllision
			if overlap_surface.x < overlap_surface.y
			{
				has_horizontal_collsion = true;
				if ball_left < slab_left
					new_ball_position.x = slab_left - g_ball.size.x;
				else 
					new_ball_position.x = slab_right;
			}
			else
			{
				has_vertical_collision = true;
				if ball_bottom < slab_bottom
					new_ball_position.y = slab_bottom - g_ball.size.y;
				else
					new_ball_position.y = slab_top;
			}

			// On Collision
			{
				slab.hp -= 1;

				// Emit Particle
				{
					particles_color := SLAB_COLORS[slab.hp];
					ball_center := g_ball.position + (g_ball.size * 0.5);

					emit_particles(ball_center, particles_color);

					g_screen_shake_timer = SCREEN_SHAKE_DURATION_S;
				}
			}
		}

		// Reflect ball direction based on collision
		if has_horizontal_collsion
			g_ball_direction.x *= -1;
		if has_vertical_collision
			g_ball_direction.y *= -1;
	
		// Set ball to new position to prevent the same overlap next frame
		g_ball.position = new_ball_position;
	}

	// Update Slabs Lifetime
	{
		i : u8 = 0;
		while i < g_slabs.count
		{
			slab := g_slabs[i];
			if slab.hp == 0
			{
				array_unordered_remove_by_index(*g_slabs, i);
				continue;
			}

			i += 1;
		}
	}

	update_particles(cast(float)delta_time);

	// Update Screen Shake
	{
		// Returns the t value of a wave of amplitude 1 and frequency 1
		wave :: (t : float) -> float
		{
			PI_2 :: 2 * PI;
			return sin(PI_2 * t); 
		}

		if g_screen_shake_timer > 0.0
		{
			screen_shake_factor := g_screen_shake_timer / SCREEN_SHAKE_DURATION_S;
			screen_shake_intensity := screen_shake_factor * SCREEN_SHAKE_MAX_INTENSITY;
			g_screen_shake_offset.x = screen_shake_intensity * wave(screen_shake_factor);

			g_screen_shake_timer -= cast(float)delta_time;
		}
		else
		{
			g_screen_shake_offset.x = 0.0;
		}
	}

	// Check Level Up
	{
		if g_slabs.count == 0
		{
			g_current_level = min(g_levels.count - 1, g_current_level + 1);
			init_objects();
		}
	}
}

draw :: ()
{
	draw_quad :: (quad : Quad, color : Vector3)
	{
		using quad;

		Simp.set_shader_for_color();

		p0 := position + g_screen_shake_offset;
		p1 := make_vector2(p0.x + size.x, p0.y);
		p2 := make_vector2(p1.x, p0.y + size.y);
		p3 := make_vector2(p0.x, p2.y);

		rgba := make_vector4(color, 1.0);

		Simp.immediate_quad(p0, p1, p2, p3, rgba);
	}

	draw_slab :: (slab : Slab)
	{
		using slab;

		if hp == 0 then return;

		assert(slab.hp <= SLAB_COLORS.count, "Not enough colors defined for each slab hp.");

		color := SLAB_COLORS[slab.hp - 1];
		outline_color := color * SLAB_OUTLINE_COLOR_MULTIPLIER;

		// draw outline
		draw_quad(quad, outline_color);

		// draw interior
		SLAB_OUTLINE_VECTOR :: Vector2.{SLAB_OUTLINE, SLAB_OUTLINE};
		slab_interior := Quad.{quad.position + SLAB_OUTLINE_VECTOR, quad.size - (2 * SLAB_OUTLINE_VECTOR)};
		draw_quad(slab_interior, color);
	}

	// Select Clear Color
	clear_color : Vector3;
	if g_pause_game then clear_color = SCREEN_PAUSE_CLEAR_COLOR;
	else clear_color = SCREEN_CLEAR_COLOR;

	Simp.clear_render_target(clear_color.x, clear_color.y, clear_color.z, 1.0);

	// Draw Game Objects
	{
		draw_quad(g_paddle, PADDLE_COLOR);
		draw_quad(g_ball, BALL_COLOR);

		for slab : g_slabs
			draw_slab(slab);

		for particle : g_particles
			draw_quad(particle.quad, particle.color);
	}

	Simp.swap_buffers(g_window.window);
}
