<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('properties', function (Blueprint $table) {
            $table->id();
            $table->ulid('ulid')->unique();
            $table->string('intern_reference')->unique();
            $table->string('title');
            $table->string('street')->nullable();
            $table->string('number')->nullable();
            $table->string('zip_code')->nullable();

            $table->boolean('is_active')->default(true);
            $table->boolean('is_sell')->default(false);
            $table->boolean('is_rent')->default(false);

            $table->decimal('sell_price', 12, 2)->nullable();
            $table->decimal('rental_price', 12, 2)->nullable();
            $table->decimal('built_m2', 10, 2)->nullable();

            $table->foreignId('office_id');
            $table->foreignId('property_type_id');
            $table->foreignId('user_id');

            $table->foreignId('neighborhood_id')->nullable();
            $table->foreignId('district_id')->nullable();
            $table->foreignId('municipality_id')->nullable();
            $table->foreignId('region_id')->nullable();
            $table->foreignId('location_id')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('properties');
    }
};
