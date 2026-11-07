<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Models\AdminPackageModel;
use App\Models\AdminTourModel;

/**
 * Gói tour (US06-S5-01, FR-07 – Nguyễn Tuấn Khôi): quản trị viên thêm gói, sửa tên / mô tả / giá người lớn và trẻ em,
 * ngừng bán hoặc bán lại. Gói không bị xóa vì đơn cũ còn ghi tên gói; đổi giá không đổi giá của đơn đã đặt.
 * Tour có ít nhất một gói đang bán thì khách phải chọn gói khi đặt tour.
 */
final class AdminPackageController extends AdminController
{
    private const MESSAGES = [
        'created' => 'Đã thêm gói tour.',
        'updated' => 'Đã lưu gói tour.',
        'unchanged' => 'Không có thay đổi nào.',
    ];

    private const EMPTY_FORM = ['package_id' => '', 'name' => '', 'description' => '', 'adult_price' => '', 'child_price' => '', 'active' => '1', 'sort_order' => '0'];

    private const PRICE_ERROR = 'Giá phải lớn hơn 0đ và không quá 100.000.000đ.';

    private AdminPackageModel $packages;

    public function __construct()
    {
        parent::__construct();
        $this->packages = new AdminPackageModel();
    }

    /** GET /admin/tours/{id}/packages?edit=<mã gói> */
    public function index(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $packages = $this->packages->list((string) $tour['tour_id']);

        $old = self::EMPTY_FORM;
        $editId = self::parseUuid($this->query('edit'));
        foreach ($packages as $package) {
            if ($package['package_id'] === $editId) {
                $old = self::oldFrom($package);
            }
        }

        $this->renderIndex($tour, $packages, $old, [], $this->flash(self::MESSAGES));
    }

    /** POST /admin/tours/{id}/packages – package_id ('' = gói mới), name, description, adult_price, child_price, active, sort_order, _csrf */
    public function save(string $id): void
    {
        $tour = $this->findTourOrFail($id);
        $tourId = (string) $tour['tour_id'];
        $old = [];
        foreach (array_keys(self::EMPTY_FORM) as $field) {
            $old[$field] = $this->input($field);
        }
        $old['active'] = $old['active'] === '1' ? '1' : '0';

        if (!$this->csrfValid()) {
            $this->renderIndex($tour, $this->packages->list($tourId), $old, ['form' => self::CSRF_FAILED], '', 403);
            return;
        }

        [$data, $errors] = self::validate($old);
        $packageId = $old['package_id'] === '' ? null : self::parseUuid($old['package_id']);
        if ($old['package_id'] !== '' && $packageId === null) {
            $errors['form'] = 'Không tìm thấy gói tour này, vui lòng tải lại trang.';
        }
        if ($errors !== []) {
            $this->renderIndex($tour, $this->packages->list($tourId), $old, $errors, '', 422);
            return;
        }

        $row = $this->packages->save($this->actorId(), $tourId, $packageId, $data);
        $back = '/admin/tours/' . $tourId . '/packages';
        match ((string) $row['result']) {
            'ok' => $this->redirect($back . '?msg=' . ($packageId === null ? 'created' : 'updated')),
            'unchanged' => $this->redirect($back . '?msg=unchanged'),
            'forbidden' => self::forbidden(),
            'duplicate' => $this->renderIndex($tour, $this->packages->list($tourId), $old, ['name' => 'Tour đã có gói cùng tên.'], '', 409),
            'invalid' => $this->renderIndex($tour, $this->packages->list($tourId), $old, self::fieldError($row['field'] ?? null), '', 422),
            default => $this->renderIndex($tour, $this->packages->list($tourId), $old, ['form' => 'Không tìm thấy gói tour này, vui lòng tải lại trang.'], '', 404),
        };
    }

    /**
     * @param array<string, string> $old
     * @return array{0: array{name: string, description: string, adult_price: int, child_price: ?int, active: bool, sort_order: int}, 1: array<string, string>}
     */
    private static function validate(array $old): array
    {
        $errors = [];
        $nameLength = mb_strlen($old['name']);
        if ($nameLength === 0) {
            $errors['name'] = 'Vui lòng nhập tên gói.';
        } elseif ($nameLength > AdminPackageModel::NAME_MAX_LENGTH) {
            $errors['name'] = 'Tên gói tối đa ' . AdminPackageModel::NAME_MAX_LENGTH . ' ký tự.';
        }
        if (mb_strlen($old['description']) > AdminPackageModel::DESCRIPTION_MAX_LENGTH) {
            $errors['description'] = 'Mô tả tối đa ' . AdminPackageModel::DESCRIPTION_MAX_LENGTH . ' ký tự.';
        }

        $adult = self::parsePrice($old['adult_price']);
        if ($old['adult_price'] === '') {
            $errors['adult_price'] = 'Vui lòng nhập giá người lớn.';
        } elseif ($adult === null) {
            $errors['adult_price'] = self::PRICE_ERROR;
        }
        $child = self::parsePrice($old['child_price']);
        if ($old['child_price'] !== '' && $child === null) {
            $errors['child_price'] = self::PRICE_ERROR;
        }

        $sort = ctype_digit($old['sort_order']) && strlen($old['sort_order']) <= 3 ? (int) $old['sort_order'] : -1;
        if ($old['sort_order'] === '') {
            $sort = 0;
        } elseif ($sort < 0 || $sort > AdminPackageModel::SORT_MAX) {
            $errors['sort_order'] = 'Thứ tự từ 0 đến ' . AdminPackageModel::SORT_MAX . '.';
        }

        return [[
            'name' => $old['name'],
            'description' => $old['description'],
            'adult_price' => (int) $adult,
            'child_price' => $child,
            'active' => $old['active'] === '1',
            'sort_order' => max(0, $sort),
        ], $errors];
    }

    /** "650.000", "650 000" hoặc "650000" → 650000; null khi không phải số tiền hợp lệ. */
    private static function parsePrice(string $value): ?int
    {
        $digits = str_replace(['.', ',', ' '], '', $value);
        if (!ctype_digit($digits) || strlen($digits) > 9) {
            return null;
        }
        $price = (int) $digits;

        return $price >= 1 && $price <= AdminPackageModel::PRICE_MAX ? $price : null;
    }

    /**
     * @param array<string, mixed> $package
     * @return array<string, string>
     */
    private static function oldFrom(array $package): array
    {
        return [
            'package_id' => (string) $package['package_id'],
            'name' => (string) $package['name'],
            'description' => (string) ($package['description'] ?? ''),
            'adult_price' => (string) $package['adult_price_vnd'],
            'child_price' => $package['child_price_vnd'] === null ? '' : (string) $package['child_price_vnd'],
            'active' => (int) $package['active'] === 1 ? '1' : '0',
            'sort_order' => (string) $package['sort_order'],
        ];
    }

    /** @return array<string, string> */
    private static function fieldError(mixed $field): array
    {
        $field = (string) $field;

        return isset(self::EMPTY_FORM[$field])
            ? [$field => 'Giá trị không hợp lệ, vui lòng kiểm tra lại.']
            : ['form' => 'Không lưu được, vui lòng kiểm tra lại thông tin.'];
    }

    /** @return array<string, mixed> */
    private function findTourOrFail(string $id): array
    {
        $tourId = self::parseUuid($id);
        $tour = $tourId === null ? null : (new AdminTourModel())->find($tourId);

        return $tour ?? self::notFound();
    }

    /**
     * @param array<string, mixed> $tour
     * @param list<array<string, mixed>> $packages
     * @param array<string, string> $old
     * @param array<string, string> $errors
     */
    private function renderIndex(array $tour, array $packages, array $old, array $errors, string $success, int $status = 200): void
    {
        $this->render('admin/packages/index', [
            'title' => 'Gói tour · ' . $tour['title'],
            'adminNav' => 'tours',
            'tour' => $tour,
            'packages' => $packages,
            'old' => $old,
            'errors' => $errors,
            'success' => $success,
            'pageStyles' => ['css/admin.css'],
        ], $status);
    }
}
