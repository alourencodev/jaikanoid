#import "Random";

PARTICLE_SPEED_MIN :: 220.0;
PARTICLE_SPEED_MAX :: 300.0;
PARTICLE_WIDTH :: 4;
PARTICLE_MIN_LIFETIME_S :: 0.005;
PARTICLE_MAX_LIFETIME_S :: 0.5;
PARTICLE_GRAVITY_ACCEL :: 9.8;
PARTICLE_COUNT :: 128;
PARTICLE_START_OFFSET_MAX :: 16;

g_particles : [..] Particle;

Particle :: struct
{
	using quad : Quad;
	color : Vector3;
	direction : Vector2;
	max_lifetime_s : float;
	lifetime_s : float64 = 0.0;
	speed : float;
}

emit_particles :: (position : Vector2, color : Vector3)
{
	for 0..(PARTICLE_COUNT - 1)
	{
		particle : Particle;
		particle.max_lifetime_s = random_get_within_range(PARTICLE_MIN_LIFETIME_S, PARTICLE_MAX_LIFETIME_S);
		particle.color = color;
		particle.size = Vector2.{PARTICLE_WIDTH, PARTICLE_WIDTH};
		particle.speed = random_get_within_range(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX);

		random_position_offset_x := random_get_within_range(-PARTICLE_START_OFFSET_MAX, PARTICLE_START_OFFSET_MAX);
		random_position_offset_y := random_get_within_range(-PARTICLE_START_OFFSET_MAX, PARTICLE_START_OFFSET_MAX);
		particle.position = position + Vector2.{random_position_offset_x, random_position_offset_y};
		
		random_direction_x := random_get_within_range(-1.0, 1.0);
		random_direction_y := random_get_within_range(-1.0, 1.0);
		random_direction := Vector2.{random_direction_x, random_direction_y};
		particle.direction = unit_vector(random_direction);

		array_add(*g_particles, particle);
	}
}

update_particles :: (delta_time : float)
{
	i := 0;
	
	while i < g_particles.count
	{
		particle := *g_particles[i];

		particle.lifetime_s += delta_time;

		particle_died := particle.lifetime_s > particle.max_lifetime_s;
		if particle_died
		{
			array_unordered_remove_by_index(*g_particles, i);
			continue;
		}

		gravity_aceleration := Vector2.{0.0, PARTICLE_GRAVITY_ACCEL * delta_time};
		particle.direction = unit_vector(particle.direction - gravity_aceleration);
		particle.position += delta_time * particle.direction * particle.speed;

		i += 1;
	}
}

