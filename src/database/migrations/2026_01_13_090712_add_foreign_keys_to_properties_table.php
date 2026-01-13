<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('properties', function (Blueprint $table) {
            $table->foreign('office_id')->references('id')->on('offices')->cascadeOnDelete();
            $table->foreign('property_type_id')->references('id')->on('property_types');
            $table->foreign('user_id')->references('id')->on('users');

            $table->foreign('neighborhood_id')->references('id')->on('neighborhoods')->nullOnDelete();
            $table->foreign('district_id')->references('id')->on('districts')->nullOnDelete();
            $table->foreign('municipality_id')->references('id')->on('municipalities')->nullOnDelete();
            $table->foreign('region_id')->references('id')->on('regions')->nullOnDelete();
            $table->foreign('location_id')->references('id')->on('locations')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('properties', function (Blueprint $table) {
            $table->dropForeign(['office_id']);
            $table->dropForeign(['property_type_id']);
            $table->dropForeign(['user_id']);
            $table->dropForeign(['neighborhood_id']);
            $table->dropForeign(['district_id']);
            $table->dropForeign(['municipality_id']);
            $table->dropForeign(['region_id']);
            $table->dropForeign(['location_id']);
        });
    }
};
