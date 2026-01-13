<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Property extends Model
{
    protected $fillable = [
        'ulid','intern_reference','title','street','number','zip_code',
        'is_active','is_sell','is_rent','sell_price','rental_price','built_m2',
        'office_id','property_type_id','user_id','secondary_user_id',
        'neighborhood_id','district_id','municipality_id','region_id','location_id'
    ];

    public function operations(): HasMany
    {
        return $this->hasMany(Operation::class);
    }

    public function propertyType(): BelongsTo
    {
        return $this->belongsTo(PropertyType::class);
    }

    public function office(): BelongsTo
    {
        return $this->belongsTo(Office::class);
    }

    public function mainAgent(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function neighborhood(): BelongsTo
    {
        return $this->belongsTo(\App\Models\Neighborhood::class);
    }

    public function district(): BelongsTo
    {
        return $this->belongsTo(\App\Models\District::class);
    }

    public function municipality(): BelongsTo
    {
        return $this->belongsTo(\App\Models\Municipality::class);
    }

    public function region(): BelongsTo
    {
        return $this->belongsTo(\App\Models\Region::class);
    }

    public function location(): BelongsTo
    {
        return $this->belongsTo(\App\Models\Location::class);
    }
}
