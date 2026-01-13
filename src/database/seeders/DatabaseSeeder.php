<?php

namespace Database\Seeders;

use App\Models\District;
use App\Models\Location;
use App\Models\Municipality;
use App\Models\Neighborhood;
use App\Models\Office;
use App\Models\Operation;
use App\Models\Property;
use App\Models\PropertyType;
use App\Models\Region;
use App\Models\Status;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $office1 = Office::create(['name' => 'Valencia Centro']);
        $office2 = Office::create(['name' => 'Madrid Centro']);

        $type1 = PropertyType::create(['name' => 'Piso']);
        $type2 = PropertyType::create(['name' => 'Chalet']);

        $neigh = Neighborhood::create(['name' => 'Centro']);
        $dist = District::create(['name' => 'Ciutat Vella']);
        $mun = Municipality::create(['name' => 'Valencia']);
        $reg = Region::create(['name' => 'L’Horta']);
        $loc = Location::create(['name' => 'Valencia']);

        $open = Status::create(['name' => 'Open', 'is_closed' => false]);
        $closed = Status::create(['name' => 'Closed', 'is_closed' => true]);

        $admin = User::create([
            'name' => 'Admin Demo',
            'email' => 'admin@demo.com',
            'password' => Hash::make('password'),
            'role' => 'admin',
            'office_id' => $office1->id,
        ]);

        $user1 = User::create([
            'name' => 'Agente Valencia',
            'email' => 'user1@demo.com',
            'password' => Hash::make('password'),
            'role' => 'user',
            'office_id' => $office1->id,
        ]);

        $user2 = User::create([
            'name' => 'Agente Madrid',
            'email' => 'user2@demo.com',
            'password' => Hash::make('password'),
            'role' => 'user',
            'office_id' => $office2->id,
        ]);

        $p1 = Property::create([
            'ulid' => (string) Str::ulid(),
            'intern_reference' => 'PROP-12345',
            'title' => 'Piso en el centro de Madrid',
            'street' => 'Calle Mayor',
            'number' => '10',
            'zip_code' => '28001',
            'is_active' => true,
            'is_sell' => true,
            'is_rent' => false,
            'sell_price' => 250000,
            'rental_price' => null,
            'built_m2' => 85,
            'office_id' => $office2->id,
            'property_type_id' => $type1->id,
            'user_id' => $user2->id,
            'neighborhood_id' => $neigh->id,
            'district_id' => $dist->id,
            'municipality_id' => $mun->id,
            'region_id' => $reg->id,
            'location_id' => $loc->id,
        ]);

        $p2 = Property::create([
            'ulid' => (string) Str::ulid(),
            'intern_reference' => 'PROP-20000',
            'title' => 'Chalet con jardín',
            'street' => 'Avenida Verde',
            'number' => '3',
            'zip_code' => '46001',
            'is_active' => true,
            'is_sell' => true,
            'is_rent' => true,
            'sell_price' => 420000,
            'rental_price' => 1600,
            'built_m2' => 140,
            'office_id' => $office1->id,
            'property_type_id' => $type2->id,
            'user_id' => $user1->id,
            'neighborhood_id' => $neigh->id,
        ]);

        $p3 = Property::create([
            'ulid' => (string) Str::ulid(),
            'intern_reference' => 'PROP-30000',
            'title' => 'Piso para alquilar',
            'street' => 'Calle Norte',
            'number' => '8',
            'zip_code' => '46002',
            'is_active' => true,
            'is_sell' => false,
            'is_rent' => true,
            'sell_price' => null,
            'rental_price' => 1200,
            'built_m2' => 70,
            'office_id' => $office1->id,
            'property_type_id' => $type1->id,
            'user_id' => $user1->id,
            'district_id' => $dist->id,
        ]);

        Operation::create(['property_id' => $p2->id, 'status_id' => $open->id]);
        Operation::create(['property_id' => $p1->id, 'status_id' => $closed->id]);

        Property::create([
            'ulid' => (string) Str::ulid(),
            'intern_reference' => 'PROP-99999',
            'title' => 'Propiedad inactiva',
            'street' => 'Calle Olvido',
            'number' => '1',
            'zip_code' => '46003',
            'is_active' => false,
            'is_sell' => true,
            'is_rent' => false,
            'sell_price' => 90000,
            'built_m2' => 50,
            'office_id' => $office1->id,
            'property_type_id' => $type1->id,
            'user_id' => $user1->id,
        ]);
    }
}
