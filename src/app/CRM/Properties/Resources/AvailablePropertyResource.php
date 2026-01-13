<?php

namespace App\CRM\Properties\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AvailablePropertyResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $operationType = $request->query('operation_type');

        if ($operationType === 'sale') {
            $price = $this->sell_price;
            $op = 'sale';
        } elseif ($operationType === 'rent') {
            $price = $this->rental_price;
            $op = 'rent';
        } else {
            if ($this->is_sell && $this->sell_price !== null) {
                $price = $this->sell_price;
                $op = 'sale';
            } elseif ($this->is_rent && $this->rental_price !== null) {
                $price = $this->rental_price;
                $op = 'rent';
            } else {
                $price = $this->sell_price ?? $this->rental_price;
                $op = $this->sell_price !== null ? 'sale' : ($this->rental_price !== null ? 'rent' : null);
            }
        }

        return [
            'id' => $this->ulid ?? (string) $this->id,
            'intern_reference' => $this->intern_reference,
            'title' => $this->title,
            'address' => $this->addressLine(),
            'property_type' => $this->whenLoaded('propertyType', fn () => [
                'id' => $this->propertyType->id,
                'name' => $this->propertyType->name,
            ]),
            'zone' => $this->zoneData(),
            'surface_m2' => $this->built_m2 !== null ? (int) round((float) $this->built_m2) : null,
            'price' => $price !== null ? (float) $price : null,
            'operation_type' => $op,
            'is_sell' => (bool) $this->is_sell,
            'is_rent' => (bool) $this->is_rent,
            'office' => $this->whenLoaded('office', fn () => [
                'id' => $this->office->id,
                'name' => $this->office->name,
            ]),
            'main_agent' => $this->whenLoaded('mainAgent', fn () => [
                'id' => $this->mainAgent->id,
                'name' => $this->mainAgent->name,
            ]),
            'created_at' => optional($this->created_at)->toISOString(),
        ];
    }

    private function addressLine(): ?string
    {
        $street = trim((string) ($this->street ?? ''));
        $number = trim((string) ($this->number ?? ''));
        $zip = trim((string) ($this->zip_code ?? ''));

        $city = null;
        if ($this->relationLoaded('municipality') && $this->municipality) {
            $city = $this->municipality->name;
        } elseif ($this->relationLoaded('location') && $this->location) {
            $city = $this->location->name;
        } elseif ($this->relationLoaded('district') && $this->district) {
            $city = $this->district->name;
        }

        $line1 = trim($street . ' ' . $number);
        $line2 = trim($zip . ' ' . ($city ?? ''));

        $parts = [];
        if ($line1 !== '') {
            $parts[] = $line1;
        }
        if ($line2 !== '') {
            $parts[] = $line2;
        }

        return count($parts) ? implode(', ', $parts) : null;
    }

    private function zoneData(): ?array
    {
        if ($this->relationLoaded('neighborhood') && $this->neighborhood) {
            return ['type' => 'neighborhood', 'id' => $this->neighborhood->id, 'name' => $this->neighborhood->name];
        }
        if ($this->relationLoaded('district') && $this->district) {
            return ['type' => 'district', 'id' => $this->district->id, 'name' => $this->district->name];
        }
        if ($this->relationLoaded('municipality') && $this->municipality) {
            return ['type' => 'municipality', 'id' => $this->municipality->id, 'name' => $this->municipality->name];
        }
        if ($this->relationLoaded('region') && $this->region) {
            return ['type' => 'region', 'id' => $this->region->id, 'name' => $this->region->name];
        }
        if ($this->relationLoaded('location') && $this->location) {
            return ['type' => 'location', 'id' => $this->location->id, 'name' => $this->location->name];
        }

        return null;
    }
}
