<?php

namespace App\CRM\Properties\Queries;

use App\Models\Property;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

class AvailableForOperationsQuery
{
    public function __construct(
        private readonly array $filters,
        private readonly User $user
    ) {}

    public function build(): Builder
    {
        $q = Property::query()
            ->where('is_active', true)
            ->whereDoesntHave('operations', function (Builder $op) {
                $op->whereHas('status', function (Builder $st) {
                    $st->where('is_closed', false);
                });
            })
            ->with([
                'propertyType:id,name',
                'office:id,name',
                'mainAgent:id,name',
                'neighborhood:id,name',
                'district:id,name',
                'municipality:id,name',
                'region:id,name',
                'location:id,name',
            ]);

        $this->applyAuthorization($q);
        $this->applyFilters($q);

        return $q->orderByDesc('created_at');
    }

    private function applyAuthorization(Builder $q): void
    {
        if ($this->canSeeAllOffices()) {
            return;
        }

        if ($this->user->office_id !== null) {
            $q->where('office_id', (int) $this->user->office_id);
        }
    }

    private function canSeeAllOffices(): bool
    {
        $role = $this->user->role;

        if (is_string($role)) {
            return in_array($role, ['admin', 'god', 'commercial_director'], true);
        }

        return false;
    }

    private function applyFilters(Builder $q): void
    {
        $f = $this->filters;

        if (array_key_exists('property_type_id', $f)) {
            $q->where('property_type_id', (int) $f['property_type_id']);
        }

        if ($this->canSeeAllOffices() && array_key_exists('office_id', $f)) {
            $q->where('office_id', (int) $f['office_id']);
        }

        if (!empty($f['zone_type']) && !empty($f['zone_id'])) {
            $col = $this->zoneColumn((string) $f['zone_type']);
            if ($col) {
                $q->where($col, (int) $f['zone_id']);
            }
        }

        $opType = $f['operation_type'] ?? null;

        if ($opType === 'sale') {
            $q->where('is_sell', true)->whereNotNull('sell_price');
            $this->applyPriceFilters($q, 'sell_price', $f);
        } elseif ($opType === 'rent') {
            $q->where('is_rent', true)->whereNotNull('rental_price');
            $this->applyPriceFilters($q, 'rental_price', $f);
        } else {
            $q->where(function (Builder $qq) {
                $qq->whereNotNull('sell_price')->orWhereNotNull('rental_price');
            });

            $min = $f['min_price'] ?? null;
            $max = $f['max_price'] ?? null;

            if ($min !== null || $max !== null) {
                $q->where(function (Builder $qq) use ($min, $max) {
                    if ($min !== null) {
                        $qq->where(function (Builder $p) use ($min) {
                            $p->where('sell_price', '>=', $min)->orWhere('rental_price', '>=', $min);
                        });
                    }
                    if ($max !== null) {
                        $qq->where(function (Builder $p) use ($max) {
                            $p->where('sell_price', '<=', $max)->orWhere('rental_price', '<=', $max);
                        });
                    }
                });
            }
        }

        if (array_key_exists('min_surface_m2', $f)) {
            $q->where('built_m2', '>=', $f['min_surface_m2']);
        }

        if (array_key_exists('max_surface_m2', $f)) {
            $q->where('built_m2', '<=', $f['max_surface_m2']);
        }

        if (!empty($f['search'])) {
            $search = mb_strtolower(trim((string) $f['search']));
            $q->where(function (Builder $qq) use ($search) {
                $qq->whereRaw('LOWER(title) LIKE ?', ['%' . $search . '%'])
                    ->orWhereRaw('LOWER(street) LIKE ?', ['%' . $search . '%'])
                    ->orWhereRaw('LOWER(intern_reference) LIKE ?', ['%' . $search . '%']);
            });
        }
    }

    private function applyPriceFilters(Builder $q, string $column, array $f): void
    {
        if (array_key_exists('min_price', $f)) {
            $q->where($column, '>=', $f['min_price']);
        }
        if (array_key_exists('max_price', $f)) {
            $q->where($column, '<=', $f['max_price']);
        }
    }

    private function zoneColumn(string $type): ?string
    {
        return match ($type) {
            'neighborhood' => 'neighborhood_id',
            'district' => 'district_id',
            'municipality' => 'municipality_id',
            'region' => 'region_id',
            'location' => 'location_id',
            default => null,
        };
    }
}