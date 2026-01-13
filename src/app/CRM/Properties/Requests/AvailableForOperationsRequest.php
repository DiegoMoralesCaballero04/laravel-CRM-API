<?php

namespace App\CRM\Properties\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AvailableForOperationsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'property_type_id' => ['nullable', 'integer'],
            'office_id' => ['nullable', 'integer'],
            'zone_type' => ['nullable', 'string', 'in:neighborhood,district,municipality,region,location'],
            'zone_id' => ['nullable', 'integer', 'required_with:zone_type'],
            'operation_type' => ['nullable', 'string', 'in:sale,rent'],
            'min_price' => ['nullable', 'numeric', 'min:0'],
            'max_price' => ['nullable', 'numeric', 'min:0', 'gte:min_price'],
            'min_surface_m2' => ['nullable', 'numeric', 'min:0'],
            'max_surface_m2' => ['nullable', 'numeric', 'min:0', 'gte:min_surface_m2'],
            'search' => ['nullable', 'string', 'max:255'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ];
    }

    public function validated($key = null, $default = null)
    {
        $data = parent::validated($key, $default);

        $data['page'] = isset($data['page']) ? (int) $data['page'] : 1;
        $data['per_page'] = isset($data['per_page']) ? (int) $data['per_page'] : 20;
        $data['per_page'] = min(max($data['per_page'], 1), 50);

        return $data;
    }
}
